#! /bin/bash
#
# Copyright (c) 2024,2025 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

DEVICE=
FILESYSTEM=xfs

EFI_PARTITION_LABEL="EFI-SYSTEM"
BOOT_PARTITION_LABEL="boot"
ROOT_PARTITION_LABEL="root"

while true; do
	case "$1" in
	"") break;;
	-d | --device ) DEVICE="$2"; shift; shift ;;
	-f | --filesystem ) FILESYSTEM="$2"; shift; shift ;;
	esac
done

if [[ -z "$FILESYSTEM" ]]; then
	echo "A filesystem is required"
	exit 1
fi

if [[ -z "$DEVICE" ]]; then
	echo "A device is required"
	exit 1
fi

EFI_DEVICE=$(blkid | grep "${DEVICE}" | grep 'PARTLABEL="EFI-SYSTEM"' | cut -f1 -d' ' | tr -d ':')
ROOT_DEVICE=$(blkid | grep "${DEVICE}" | grep 'PARTLABEL="root"' | cut -f1 -d' ' | tr -d ':')
BOOT_DEVICE=$(blkid | grep "${DEVICE}" | grep 'PARTLABEL="boot"' | cut -f1 -d' ' | tr -d ':')

# Make filesystems
mkfs.fat -F 32 -n "$EFI_PARTITION_LABEL" "$EFI_DEVICE"
mkfs.xfs -f -m bigtime=0,inobtcount=0,reflink=0 -L "$BOOT_PARTITION_LABEL" "$BOOT_DEVICE"
"mkfs.$FILESYSTEM" -f -m bigtime=0,inobtcount=0,reflink=0 -L "$ROOT_PARTITION_LABEL" "$ROOT_DEVICE"

