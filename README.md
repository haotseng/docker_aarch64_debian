

## Prepare environment

OS: x86 Debian 8 (Jessie)

Before you start, Some packets must be installed in you environment.

    # apt-get install binfmt-support qemu qemu-user-static debootstrap


## Build root file system

Run `gen_debian_aarch64_rootfs.sh` to generate the rootfs.tar.gz into output directory.

    # ./gen_debian_aarch64_rootfs.sh


## Build docker image

Use Dockerfile to build image

    # docker build -t aarch64-debian .

    
