#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x
set -e

DISK=

while true; do
	case "$1" in
	"") break;;
	-D | --disk ) DISK="$2"; shift; shift ;;
	esac
done

if [[ -z "$DISK" ]]; then
	echo "A disk is required"
	exit 1
fi

TMP_DISK="$DISK-tmp"
qemu-img convert -c -f qcow2 -O qcow2 "$DISK" "$TMP_DISK"
rm "$DISK"
cp --sparse=always "$TMP_DISK" "$DISK"
rm "$TMP_DISK"
