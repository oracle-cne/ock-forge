#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x
set -e

DEVICE=
MOUNT=
FILESYSTEM=xfs
IMAGE=
CONFIG_DIR=
CLEAN=yes
OSTREE_IMAGE_PATH=
FORMAT_DISK=

OS_NAME=ock

echo "$@"

while true; do
	case "$1" in
	"") break;;
	-d | --device ) DEVICE="$2"; shift; shift ;;
	-m | --mount ) MOUNT="$2"; shift; shift ;;
	-f | --filesystem ) FILESYSTEM="$2"; shift; shift ;;
	-i | --image ) IMAGE="$2"; shift; shift ;;
	-c | --config-dir ) CONFIG_DIR="$2"; shift; shift ;;
	-o | --os-name ) OS_NAME="$2"; shift; shift ;;
	-n | --no-clean ) CLEAN=; shift ;;
	-O | --ostree-image-path ) OSTREE_IMAGE_PATH="/out/$2"; shift; shift ;;
	-F | --format-disk ) FORMAT_DISK=yes; shift ;;
	* ) echo "$1 is not a valid agument"; exit 1 ;;
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

if [[ -z "$IMAGE" && -z "$CONFIG_DIR" ]]; then
	echo "A container image or treefile is required"
	exit 1
fi

mount --bind /var/tmp /tmp

if [[ -n "$FORMAT_DISK" ]]; then
	./format-disk.sh -d "$DEVICE" -f "$FILESYSTEM"
fi

./make-mounts.sh -d "$DEVICE" -m "$MOUNT"
./deploy-ostree.sh -d "$DEVICE" -m "$MOUNT" -i "$IMAGE" -c "$CONFIG_DIR" -o "$OS_NAME" -O "$OSTREE_IMAGE_PATH"
./install-bootloader.sh -d "$DEVICE" -m "$MOUNT" -o "$OS_NAME"  -f "$FILESYSTEM"
