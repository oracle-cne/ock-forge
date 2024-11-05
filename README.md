# ock-forge - The Oracle Container Host for Kubernetes Builder

ock-forge is a tool that builds boot media for Oracle Container Host for
Kubernetes based on a treefile-based configuration.  It supports generating
bootable media via the qcow2 format, raw disk images, or writing
directory to an existing block device.

# Requirements

## Operating System

This project is intended to build on Oracle Linux 8 and 9.

## Privilege

Many steps of the build process require considerable privilege.  It is
highly recommend to build this project as root.  You may find some success
with `sudo` if you know what you're doing.

## Additional Software

Podman is required to use the tool.  If this tool is being used on an Oracle
Linux system, refer to the [Podman Installation Guide](https://docs.oracle.com/en/operating-systems/oracle-linux/podman/podman-InstallingPodmanandRelatedUtilities.html#podman-install)
When building qcow2 images, the `qemu-img` utility is leveraged to manipulate
the image.  When building these kind of images, `qemu-img` must be installed.
On Oracle Linux systems it can be installed via `dnf install qemu-img`.

# Using `ock-forge`

ock-forge is a set of shell scripts broken up into logical operations
that can be used and edited as necessary.  If boot media is being deployed to
a host with a simple disk geometry (which is the recommended way to deploy
OCK) then the top level command, `ock-forge`, can be used.

## `ock-forge`

The `ock-forge` command performs all the work required to generate 
OCK boot media assuming that the target is a single block device using the
standard partition layout.  It can generate boot media three ways: creating and
installing to a qcow2 image, creating and installing to a raw iso, and
installing to an arbitrary paritionable block device (read: physical disk).
In addition to generating the boot media, it creates a container image containing
the ostree contents for the build.  This container image is useful for updating
existing hosts in-place.

### Usage

These are the arguments for `ock-forge`:

```
ock-forge

 -s | --source *URI*

  A path to either a Git repository or a directory.  The contents of the
  location is copied to the build directory.  If this option is omitted,
  the existing configuration is used.

 -b | --branch *branch-name*

  The name of a Git branch.  If this option is given, the indicated branch
  is cloned.  Without this option, the default branch is cloned.

 -d | --device *block-device*

  The path to an existing block device.  This device is the installation target.
  All operations performed by the image builder are executed against this
  device.

 -D | --disk *image-path*

  The path to a disk image file.  This values is only necessary if the
  installation target is actually a file rather than a raw device.  This file
  is attached to the device specified with -d.

 -f | --filesystem *filesystem*

  The filesystem to use when formatting the root partition.  Only xfs is
  supported.

 -i | --image *container-image*

  A fully qualified container image name, including a tag.  This argument is
  used in multiple ways.  If given alone, this container image is used as the
  base image to deploy the OS.  In this case, building the ostree is skipped
  entirely.  If given with -c as well as -O, it is used to generate an ostree
  container image that can be used for later installations or upgrades.

 -s | --source *URI*

  The URI of an OCK configuration.  The configuration is copied from this
  location into the value of the `-C` argument. If the URI ends with `.git`,
  the assumption is that it refers to a Git repository.  Otherwise, the URI
  is assumed to refer to a directory on the local filesystem.

 -b | --branch

  If `-s` refers to a Git repository, check out this branch after cloning.

 -C | --configs-dir *path*

  A directory containing a set of rpm-ostree configurations.

 -c | --config-dir *path*

  A directory containing the rpm-ostree configuration to build.  This must be
  a subdirectory of `--configs-dir`, at whatever depth is required to ensure
  that all symlinks can be resolved.  If this option is specified, a complete
  rpm-ostree build is performed and optionally packaged into an OCI (Open
  Container Initiative) archive.

 -o | --os-name *name*

  The name of the ostree deployment.

 -O | --ostree-image-path *path*

  The path to write the OCI (Open Container Initiative) archive generated by the
  installation process.  If this value is not specified, no archive is generated.
  If -c is not provided, this option is ignored.  If -i is provided and points
  to a valid ostree container image, it is used as the reference for generating
  a chunked image.

 -n | --no-clean

  If this option is provided, do not perform any post-install cleanup steps like
  unmounting partitions or detaching virtual block devices.

 -P | --partition

  If this option is provided, the block device specified by -d will have its
  partition table wiped and repopulated with the default geometry.
```

### Partition Layout

Installing to a disk with existing partitions requires at least the following
partitions
- An EFI partition
- A boot partition labelled "boot"
- A root partition labelled "root"

It is strongly recommended that the disk contain only these three partitions
and that the root partition is the last partition on the disk.  The root
partition should be last to allow that partition to be automatically expanded
to fill the entire disk when the OS boots for the first time.  There are other
functional layouts, but these have limited applicability and require a good
understanding of how partitions are laid out and used.

### Configurations

`ock-forge` builds media from an [rpm-ostree treefile](https://coreos.github.io/rpm-ostree/treefile).
While it can build an arbitrary treefile, it is intended for use with Oracle
Container Host for Kubernetes (OCK).  The configurations for OCK can be found
at https://github.com/oracle-cne/ock.

### Examples

These examples assume that you have either tried the first example, or cloned
the OCK GitHub repository into your working directory with a folder named "ock".

The OCK configuration can be cloned like so:
```
# git clone https://github.com/oracle-cne/ock
```

#### Building From Git

`ock-forge` can copy configurations from inconventient places to more
convenient places.  This command builds a qcow2 and ostree image from scratch
using the OCK GitHub repository as a source of truth.  The clone of repository
is retained so it can be reused in later invocations.

```
# ./ock-forge -d /dev/nbd0 -D out/1.30/boot.qcow2 -i container-registry.oracle.com/olcne/ock-ostree:1.30 -O ./out/1.30/archive.tar -C ./ock -c configs/config-1.30 -P -s https://github.com/oracle-cne/ock.git
```

#### A Typical Build

A typical invocation builds qcow2 images.  The call to `ock-forge` relies on the tool
to do all the work required.  This invocation will generate a new qcow2 image,
attach it as a block device, partition the disk, format the partitions, install
the OS, and generate an ostree archive.

```
# ock-forge -d /dev/nbd0 -D out/1.30/boot.qcow2 -i container-registry.oracle.com/olcne/ock-ostree:1.30 -O ./out/1.30/archive.tar -C ./ock -c configs/config-1.30 -P
```

#### A Typical Build, But With a Raw Disk

This invocation does all the stuff that the previous example does, but generates
a raw disk image rather than a qcow2.  The generated image can be dd'ed onto a
physical disk and used to boot a system directly.

```
# ock-forge -d /dev/loop0 -D out/1.30/boot.iso -i container-registry.oracle.com/olcne/ock-ostree:1.30 -O ./out/1.30/archive.tar -C ./ock -c configs/config-1.30 -P
```

#### Install to a Physical Disk

Install to a physical block device, creating partitions.

```
# ock-forge -d /dev/sdb -i container-registry.oracle.com/olcne/ock-ostree:1.30 -O ./out/1.30/archive.tar -C ./ock -c configs/config-1.30 -P
```

#### Install but don't Generate an Ostree Archive

Perform a fresh installation of the OS, but do not store the contents in an
ostree container image archive.

```
# ock-forge -d /dev/nbd0 -C ./ock -c configs/config-1.30 -P
```

#### Install from a Container Image

Install using an existing ostree container image as a source.

```
# ock-forge -d /dev/nbd0 -d /dev/loop0 -D out/1.30/boot.iso -i container-registry.oracle.com/olcne/ock-ostree:1.30 -P
```

## Other Utilities

`ock-forge` is implemented via a set of other utilities.  Each of them can be
useful by themselves, usually with at least some amount of editing.

### Creating and Attaching Qcow2 Disk Images

`setup-vm-disk.sh` is can be used to create a new qcow2 image and attach it to
a network block device.

```
setup-vm-disk.sh -d *network-block-device* -D *path-to-new-image*
```

#### Example

This example makes a qcow2 image and attaches it to /dev/nbd0.

```
# setup-vm-disk -d /dev/nbd0 -D mydisk.qcow2
```

### Sparsifying Qcow2 Images

`sparsify-image.sh` can be used to re-sparsify and compress a qcow2 image.
It does part of the job of `virt-sparsify` and the result is not as good.
However, it has the advantage of not requiring a virtual machine and can
be used in environments where launching a virutal machine is not an otion.
For example, building an image inside an ARM virtual machine.  It does
require several gigabytes of storage while the command is running.  That
space is released by the time the script ends.

```
sparsify-image.sh -D *path-to-image*
```

#### Example

This example sparsifies and compresses an existing qcow2 image.

```
# sparsify-image.sh -D mydisk.qcow2
```

### Partitioning Disks

`make-partitions.sh` partitions a disk using a standard layout.  It creates
a small EFI partition as partition 1, a small boot partition as partition 2,
and a root partition with the rest of the disk as the last partition.

```
make-partitions.sh -d *path-to-device* -f *filesystem*
```

#### Example

This example partitions a physical block device using xfs.

```
make-partitions.sh -d /dev/sdb -f xfs
```

## Contributing

This project welcomes contributions from the community. Before submitting a pull request, please [review our contribution guide](./CONTRIBUTING.md)

## Security

Please consult the [security guide](./SECURITY.md) for our responsible security vulnerability disclosure process

## License

Copyright (c) 2024 Oracle and/or its affiliates.

Released under the Universal Permissive License v1.0 as shown at
<https://oss.oracle.com/licenses/upl/>.
