#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -e
set -x

MOUNT=
DEVICE=
IMAGE=
CONFIG_DIR=

SKOPEO_TRANSPORT="oci-archive"
OSTREE_TRANSPORT="ostree-unverified-registry"
OSTREE_IMAGE_PATH=

while true; do
	case "$1" in
	"") break;;
	-d | --device ) DEVICE="$2"; shift; shift ;;
	-m | --mount ) MOUNT="$2"; shift; shift ;;
	-i | --image ) IMAGE="$2"; shift; shift ;;
	-c | --config-dir ) CONFIG_DIR="$2"; shift; shift ;;
	-o | --os-name ) OS_NAME="$2"; shift; shift ;;
	-O | --ostree-image-path ) OSTREE_IMAGE_PATH="$2"; shift; shift ;;
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

if [[ -z "$IMAGE" && -z "$CONFIG_DIR" ]]; then
	echo "A container image or treefile is required"
	exit 1
fi

OSTREE="$MOUNT/ostree"
OSTREE_REPO="$OSTREE/repo"

# Deploy the ostree
ostree admin init-fs --modern "$MOUNT"
ostree config --repo "$OSTREE_REPO" set sysroot.readonly true
ostree admin os-init "$OS_NAME" --sysroot "$MOUNT"

if [[ -n "$CONFIG_DIR" ]]; then
	CACHE_DIR=/var/tmp
	mkdir -p "$CACHE_DIR"

	rpm-ostree compose tree --unified-core --cachedir="$CACHE_DIR" --repo="$OSTREE_REPO" "$CONFIG_DIR/manifest.yaml"
	if [[ -n "$OSTREE_IMAGE_PATH" ]]; then
		IMG="docker://$IMAGE"
		COMPARE_WITH=
		skopeo inspect "$IMG" > /dev/null && COMPARE_WITH="--compare-with-build $IMG" || true
		rpm-ostree compose container-encapsulate --repo="$OSTREE_REPO" $COMPARE_WITH "$OS_NAME" "$SKOPEO_TRANSPORT:$OSTREE_IMAGE_PATH:$IMAGE"
		gzip "$OSTREE_IMAGE_PATH"
	fi
elif [[ -n "$IMAGE" ]]; then
	ostree container unencapsulate --repo="$OSTREE_REPO" --write-ref "$OS_NAME" "$OSTREE_TRANSPORT:$IMAGE"
else
	echo "Internal error: either a container image or treefile directory must be specified"
	exit 1
fi

ostree admin deploy --sysroot "$MOUNT" --os "$OS_NAME" "$OS_NAME"
