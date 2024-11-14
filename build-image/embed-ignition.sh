#! /bin/bash
set -e
set -x

IGNITION=
INITRD=

while true; do
	case "$1" in
	"") break;;
	-I | --ignition ) IGNITION="$2"; shift; shift ;;
	-i | --initrd ) INITRD="$2"; shift; shift ;;
	esac
done

if [[ -z "$IGNITION" ]]; then
	echo "An ignition file is required"
	exit 1
fi

if [[ -z "$INITRD" ]]; then
	echo "An initramfs file is required"
	exit 1
fi

IGNITION=$(realpath "$IGNITION")
IGN_DIR=$(dirname "$IGNITION")

INITRD=$(realpath "$INITRD")
INITRD_DIR=$(dirname "$INITRD")
mv "$INITRD" "$INITRD_DIR/initrd.orig"

pushd "$IGN_DIR"
echo ./$(basename "$IGNITION") | cpio -oc | gzip -c > "$INITRD_DIR/ignition.cpio.gz"
popd

cat "$INITRD_DIR/initrd.orig" "$INITRD_DIR/ignition.cpio.gz" > "$INITRD"
rm -f "$INITRD_DIR/initrd.orig"
rm -f "$INITRD_DIR/ignition.cpio.gz" 
