#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

DEVICE=
MOUNT=
FILESYSTEM=xfs
OS_NAME=ock
IGNITION=
IGNITION_PROVIDER=

mount_rbind() {
	root="$1"
	fs="$2"
	mount --rbind "$fs" "$root$fs"
}

mount_bind(){
	root="$1"
	fs="$2"
	mount --bind "$fs" "$root$fs"
}

while true; do
	case "$1" in
	"") break;;
	-d | --device ) DEVICE="$2"; shift; shift ;;
	-m | --mount ) MOUNT="$2"; shift; shift ;;
	-f | --filesystem ) FILESYSTEM="$2"; shift; shift ;;
	-o | --os-name ) OS_NAME="$2"; shift; shift ;;
	-I | --ignition ) IGNITION="$2"; shift; shift ;;
	-p | --provider ) IGNITION_PROVIDER="$2"; shift; shift ;;
	esac
done

if [[ -z "$DEVICE" ]]; then
	echo "A device is required"
	exit 1
fi

if [[ -z "$MOUNT" ]]; then
	echo "A mount point is required"
	exit 1
fi

if [[ -z "$FILESYSTEM" ]]; then
	echo "A filesystem is required"
	exit 1
fi

EFI_DEVICE=$(blkid | grep "${DEVICE}" | grep 'LABEL="EFI-SYSTEM"' | cut -f1 -d' ' | tr -d ':')
ROOT_DEVICE=$(blkid | grep "${DEVICE}" | grep 'LABEL="root"' | cut -f1 -d' ' | tr -d ':')
BOOT_DEVICE=$(blkid | grep "${DEVICE}" | grep 'LABEL="boot"' | cut -f1 -d' ' | tr -d ':')

OSTREE="$MOUNT/ostree"
OSTREE_REPO="$OSTREE/repo"
IMAGE_NAME=$(echo "$IMAGE" | cut -d':' -f 2,3)

EFI_FILESYSTEM_UUID=$(blkid -o value -s UUID "$EFI_DEVICE")
BOOT_FILESYSTEM_UUID=$(blkid -o value -s UUID "$BOOT_DEVICE")
ROOT_FILESYSTEM_UUID=$(blkid -o value -s UUID "$ROOT_DEVICE")

COMMIT=$(ostree --repo="$OSTREE_REPO" rev-parse $OS_NAME)
DEPLOY="${OSTREE}/deploy/${OS_NAME}/deploy/${COMMIT}.0"
SYSROOT="${DEPLOY}/sysroot"

# Create the necessary config files
# - fstab
# - tmpfs
# - bootloader config

cat > "$DEPLOY/etc/fstab" << EOF
UUID=$ROOT_FILESYSTEM_UUID / $FILESYSTEM defaults 0 0
UUID=$BOOT_FILESYSTEM_UUID /boot xfs defaults,sync 0 0
UUID=$EFI_FILESYSTEM_UUID /boot/efi vfat defaults,uid=0,gid=0,umask=077,shortname=winnt 0 2
EOF

cat > "$DEPLOY/etc/default/grub" << EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial"
GRUB_CMDLINE_LINUX="rw ip=dhcp rd.neednet=1 ignition.platform.id=${IGNITION_PROVIDER} ignition.firstboot=1 crashkernel=auto console=ttyS0"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
EOF

# Install the bootloader

#mount -t tmpfs tmpfs "$DEPLOY/run"
#mount -t proc proc "$DEPLOY/proc"
#mount -t sysfs sys "$DEPLOY/sys"
#mount -t efivarfs  efivarfs "$DEPLOY/sys/firmware/efi/efivars"

#mount_bind "$DEPLOY" /var

# Handle dev special to avoid problems unmounting /dev/pts
#mount_bind "$DEPLOY" /dev
#mount_bind "$DEPLOY" /dev/hugepages
#mount_bind "$DEPLOY" /dev/mqueue
#mount_bind "$DEPLOY" /dev/shm

mount --rbind "$MOUNT" "$SYSROOT"

cp -rn "$DEPLOY/usr/lib/ostree-boot/efi" "$MOUNT/boot"
cp -rn "$DEPLOY/usr/lib/ostree-boot/grub2" "$MOUNT/boot"

# Count on shell expansion to get the right kernel and initramfs.  Since
# there is only one kernel per ostree commit, this should be okay?
BOOT_DIR_PATH_LEN=$(realpath $(echo ${MOUNT}/boot/) | wc -c)
BOOT_OSTREE_PATH=$(realpath $(echo ${MOUNT}/boot/ostree/ock-*))
KERNEL_PATH=$(realpath $(echo ${BOOT_OSTREE_PATH}/vmlinuz-*))
INITRAMFS_PATH=$(realpath $(echo ${BOOT_OSTREE_PATH}/initramfs-*))
KERNEL_PATH_REL=$(echo $KERNEL_PATH | tail -c +${BOOT_DIR_PATH_LEN})
INITRAMFS_PATH_REL=$(echo $INITRAMFS_PATH | tail -c +${BOOT_DIR_PATH_LEN})
OSTREE_PATH=$(echo ${MOUNT}/ostree/boot.1/ock/*/0 | tail -c +$(echo -n ${MOUNT}/ | wc -c))

cat > "$MOUNT/boot/loader/entries/ostree-1-ock.conf" << EOF
title Oracle Linux Server 8.10 17 (ostree:0)
version 1
options rw ip=dhcp rd.neednet=1 ignition.platform.id=${IGNITION_PROVIDER} ignition.firstboot=1 crashkernel=auto console=ttyS0 root=UUID=${ROOT_FILESYSTEM_UUID} ostree=${OSTREE_PATH} rd.timeout=120
linux ${KERNEL_PATH_REL}
initrd ${INITRAMFS_PATH_REL}
EOF

cat /usr/lib/bootupd/grub2-static/grub-static-pre.cfg /usr/lib/bootupd/grub2-static/grub-static-efi.cfg /usr/lib/bootupd/grub2-static/grub-static-post.cfg > "${MOUNT}/boot/efi/EFI/redhat/grub.cfg"

# If there is an ignition file, embed it into the initramfs
if [ -n "$IGNITION" ]; then
	./embed-ignition.sh -I "$IGNITION" -i "$INITRAMFS_PATH"
fi

rm -rf "${DEPLOY}/sysroot/tmp/*"
