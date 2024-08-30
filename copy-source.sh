#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x
set -e

SOURCE=
TARGET=./copy
BRANCH=

while true; do
	case "$1" in
	"") break;;
	-s | --source ) SOURCE="$2"; shift; shift; ;;
	-t | --target ) TARGET="$2"; shift; shift ;;
	-b | --branch ) BRANCH="$2"; shift; shift ;;
	esac
done

if [[ -z "$SOURCE" ]]; then
	echo "A source is required"
	exit 1
fi

if [[ -z "$TARGET" ]]; then
	echo "A target is required"
	exit 1
fi

if echo "$SOURCE" | grep '\.git$'; then
	if [[ -z "$BRANCH" ]]; then
		git clone "$SOURCE" "$TARGET"
	else
		git clone --branch "$BRANCH" --single-branch "$SOURCE" "$TARGET"
	fi
else
	cp -r "$SOURCE" "$TARGET"
fi
