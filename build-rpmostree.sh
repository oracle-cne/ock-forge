#! /bin/bash
#
# Copyright (c) 2024, Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
set -x
OUT_DIR="$1"

podman run --http-proxy --privileged --security-opt label=disable --rm -i -v "$OUT_DIR":/out container-registry.oracle.com/os/oraclelinux:9 sh <<-EOF
set -x
set -e
# Set up RPM build environment
dnf install -y rpmdevtools rpm-build
rpmdev-setuptree
dnf download --source rpm-ostree-2024.3-4.el9_4
rpm -U ./rpm-ostree-*.src.rpm

# apply necessary patches
cat ~/rpmbuild/SPECS/rpm-ostree.spec
cat > ~/rpmbuild/SOURCES/0005-scripts-ignore-kernel-uek-core.posttrans.patch <<-PATCHEOF
diff -uNr a/rust/src/scripts.rs b/rust/src/scripts.rs
--- a/rust/src/scripts.rs 2024-02-13 17:02:48.297043715 +0000
+++ b/rust/src/scripts.rs 2024-02-13 17:06:06.885021692 +0000
@@ -42,6 +42,7 @@
     "kernel-64k-debug-modules.posttrans",
     // Additionally ignore posttrans scripts for the Oracle Linux \\\`kernel-uek\\\` package
     "kernel-uek.posttrans",
+    "kernel-uek-core.posttrans",
     // Legacy workaround
     "glibc-headers.prein",
     // workaround for old bug?
PATCHEOF
cat ~/rpmbuild/SOURCES/0005-scripts-ignore-kernel-uek-core.posttrans.patch
sed -i '/Patch4: 0004-core-also-wrap-kernel-install-for-scriptlets.patch/a Patch5: 0005-scripts-ignore-kernel-uek-core.posttrans.patch' ~/rpmbuild/SPECS/rpm-ostree.spec

# Install build dependencies
yum-builddep -y --enablerepo '*' ~/rpmbuild/SPECS/rpm-ostree.spec
dnf install libxslt-1.1.34-9.0.1.el9_5.1

# Build the patched RPM
rpmbuild -ba ~/rpmbuild/SPECS/rpm-ostree.spec
cp ~/rpmbuild/RPMS/*/*.rpm /out
EOF
