#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

DEVICE=
DISK=


while true; do
	case "$1" in
	"") break;;
	-d | --device ) DEVICE="$2"; shift; shift ;;
	-D | --disk ) DISK="$2"; shift; shift ;;
	esac
done

if [[ -z "$DISK" ]]; then
	echo "A disk is required"
	exit 1
fi

if [[ -z "$DEVICE" ]]; then
	echo "A device is required"
	exit 1
fi

OUT_DIR=$(dirname "$DISK")

# If the disk does not already exist, make it
if [ ! -f "$DISK" ]; then
	mkdir -p "$OUT_DIR"
	qemu-img create -f qcow2 "$DISK" 15G
fi

# Attach it to the nbd device
qemu-nbd --connect=$DEVICE "$DISK"
