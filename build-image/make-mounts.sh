#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

DEVICE=
MOUNT=

while true; do
	case "$1" in
	"") break;;
	-d | --device ) DEVICE="$2"; shift; shift ;;
	-m | --mount ) MOUNT="$2"; shift; shift ;;
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

EFI_DEVICE=$(blkid | grep "${DEVICE}" | grep 'LABEL="EFI-SYSTEM"' | cut -f1 -d' ' | tr -d ':')
ROOT_DEVICE=$(blkid | grep "${DEVICE}" | grep 'LABEL="root"' | cut -f1 -d' ' | tr -d ':')
BOOT_DEVICE=$(blkid | grep "${DEVICE}" | grep 'LABEL="boot"' | cut -f1 -d' ' | tr -d ':')

if [[ -z "$EFI_DEVICE" ]]; then
	echo "Could not find EFI partition"
	exit 1
fi

if [[ -z "$ROOT_DEVICE" ]]; then
	echo "Could not find a root partition"
	exit 1
fi

if [[ -z "$BOOT_DEVICE" ]]; then
	echo "Could not find a boot partition"
	exit 1
fi


# Make sure the target directory exists
mkdir -p "$MOUNT"

# Mount the disks
mount "$ROOT_DEVICE" "$MOUNT"
mkdir -p "$MOUNT/boot"
mount "$BOOT_DEVICE" "$MOUNT/boot"
mkdir -p "$MOUNT/boot/efi"
mount "$EFI_DEVICE" "$MOUNT/boot/efi"
