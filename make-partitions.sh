#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

DEVICE=
FILESYSTEM=xfs

EFI_PARTITION_NUMBER=0
EFI_PARTITION_SIZE='256'
EFI_PARTITION_LABEL="EFI-SYSTEM"
EFI_PARTITION_UUID="C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
BOOT_PARTITION_NUMBER=1
BOOT_PARTITION_SIZE='512'
BOOT_PARTITION_LABEL="boot"
ROOT_PARTITION_NUMBER=2
ROOT_PARTITION_LABEL="root"

EFI_PARTITION_START='1'
EFI_PARTITION_END=$((EFI_PARTITION_START+EFI_PARTITION_SIZE))
BOOT_PARTITION_START=$((EFI_PARTITION_END+1))
BOOT_PARTITION_END=$((BOOT_PARTITION_START+BOOT_PARTITION_SIZE))
ROOT_PARTITION_START=$((BOOT_PARTITION_END+1))

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

EFI_DEVICE="${DEVICE}p$((EFI_PARTITION_NUMBER+1))"
BOOT_DEVICE="${DEVICE}p$((BOOT_PARTITION_NUMBER+1))"
ROOT_DEVICE="${DEVICE}p$((ROOT_PARTITION_NUMBER+1))"

# Partition the disk
# - EFI
# - Boot
# - Root filesystem
parted -s "$DEVICE" mklabel gpt
udevadm trigger
udevadm settle

parted -s "$DEVICE" mkpart "$EFI_PARTITION_LABEL" fat32 "$EFI_PARTITION_START" "$EFI_PARTITION_END"
parted -s "$DEVICE" mkpart "$BOOT_PARTITION_LABEL" xfs "$BOOT_PARTITION_START" "$BOOT_PARTITION_END"
parted -s "$DEVICE" mkpart "$ROOT_PARTITION_LABEL" "$FILESYSTEM" "$ROOT_PARTITION_START" '100%'
sgdisk -t "$EFI_PARTITION_NUMBER:$EFI_PARTITION_UUID" "$DEVICE"
udevadm trigger
udevadm settle
