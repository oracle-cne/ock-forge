FROM container-registry.oracle.com/os/oraclelinux:9

ADD rpm-ostree-debuginfo-2024.3-4.el9.x86_64.rpm rpm-ostree-devel-2024.3-4.el9.x86_64.rpm rpm-ostree-libs-debuginfo-2024.3-4.el9.x86_64.rpm rpm-ostree-2024.3-4.el9.x86_64.rpm rpm-ostree-debugsource-2024.3-4.el9.x86_64.rpm rpm-ostree-libs-2024.3-4.el9.x86_64.rpm /
RUN dnf install --enablerepo='*' /rpm-ostree* && \
    dnf install skopeo \
		ostree \
		bootupd \
		xfsprogs \
		dosfstools \
		qemu-img \
		parted \
		gdisk \
		systemd-udev \
		util-linux-core \
		selinux-policy-targeted \
		crypto-policies-scripts && \
    update-crypto-policies --set DEFAULT:SHA1

ADD deploy-ostree.sh install-bootloader.sh make-image.sh make-mounts.sh format-disk.sh /

ENTRYPOINT ["/make-image.sh"]
