#!/bin/bash

#
# build aarch64 rootfs for docker.
#

THIS_SCRIPT=`echo $0 | sed "s/^.*\///"`
SCRIPT_PATH=`echo $0 | sed "s/\/${THIS_SCRIPT}$//"`
real_pwd=`pwd`
real_pwd=`realpath ${real_pwd}`
output_dir=${real_pwd}/output
work_dir=${real_pwd}/_build_tmp


if [ $EUID -ne 0 ]; then
  echo "this tool must be run as root"
  exit_process 1
fi

if [ -d $work_dir ]; then
    echo "Working directory $work_dir exist, please remove it before run this script"
    exit 1
fi

mkdir -p $work_dir
mkdir -p $output_dir

#
# Debian parameters
#
#deb_mirror="http://http.debian.net/debian"
deb_mirror="http://ftp.tw.debian.org/debian"
#deb_local_mirror="http://debian.kmp.or.at:3142/debian"

deb_release="jessie"
rootfs="${work_dir}/rootfs"

architecture="arm64"
#architecture="armel"

if [ "$deb_local_mirror" == "" ]; then
  deb_local_mirror=$deb_mirror
fi

#
# 1st stage
#
mkdir -p $rootfs
debootstrap --foreign --arch $architecture --variant=minbase $deb_release $rootfs $deb_local_mirror
cp /usr/bin/qemu-aarch64-static ${rootfs}/usr/bin/

#
# 2nd stage
#
LANG=C chroot $rootfs /debootstrap/debootstrap --second-stage


cat << EOF > ${rootfs}/etc/apt/sources.list
deb $deb_local_mirror $deb_release main contrib non-free
EOF

echo "bsms" > ${rootfs}/etc/hostname

cat << EOF > ${rootfs}/etc/resolv.conf
nameserver 8.8.8.8
EOF

cat << EOF > ${rootfs}/etc/network/interfaces
auto lo
iface lo inet loopback
EOF

#
# 3rd stage
#
export MALLOC_CHECK_=0 # workaround for LP: #520465
export LC_ALL=C
export DEBIAN_FRONTEND=noninteractive

mount -t proc proc ${rootfs}/proc
mount -o bind /dev/ ${rootfs}/dev/
mount -o bind /dev/pts ${rootfs}/dev/pts

cat << EOF > ${rootfs}/debconf.set
console-common console-data/keymap/policy select Select keymap from full list
console-common console-data/keymap/full select en-latin1-nodeadkeys
EOF

cat << EOF > ${rootfs}/third-stage
#!/bin/bash
rm -rf /debootstrap
debconf-set-selections /debconf.set
rm -f /debconf.set
apt-get update
apt-get -y install locales console-common
sed -i -e 's/KERNEL\!=\"eth\*|/KERNEL\!=\"/' /lib/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules
rm -f /third-stage
EOF

chmod +x ${rootfs}/third-stage
LANG=C chroot ${rootfs} /third-stage

#
# Manual Configuration Within the chroot
#

#LANG=C chroot ${rootfs}
#{make additional changes within the chroot}
#exit


#
# Cleanup
# 
cat << EOF > ${rootfs}/cleanup
#!/bin/bash
rm -rf /root/.bash_history
apt-get clean -y
apt-get autoclean -y
apt-get autoremove -y
rm -f cleanup
EOF

chmod +x ${rootfs}/cleanup
LANG=C chroot ${rootfs} /cleanup

#
# Reduce size by delete some files
#
mkdir -p ${work_dir}/tmp
cp -R ${rootfs}/usr/share/locale/en\@* ${work_dir}/tmp/ && rm -rf ${rootfs}/usr/share/locale/* && mv ${work_dir}/tmp/en\@* ${rootfs}/usr/share/locale/
rm -rf ${rootfs}/var/cache/debconf/*-old && rm -rf ${rootfs}/var/lib/apt/lists/* && rm -rf ${rootfs}/usr/share/doc/*

sync

sleep 3

# The 'qemu-aarch64-static' will occurpy some device resource. It will cause the 'umount' don't work.
# Because the ${rootfs}/dev/ is occupied by qemu-aarch64-static.
# So, before umount all device, we must kill the 'qemu-aarch64-static' process.
ps -ef | grep qemu-aarch64-static | awk '{print $2}' | xargs kill -9

sleep 2
umount ${rootfs}/proc
sleep 2
umount ${rootfs}/dev/pts
sleep 2
umount ${rootfs}/dev/
sleep 2

rm -rf ${rootfs}/usr/bin/qemu-aarch64-static
sleep 2

# Generate rootfs tar-ball
sync
rm -rf $output_dir/rootfs.tar.gz
( cd ${rootfs}; tar -zcvf ${output_dir}/rootfs.tar.gz *; )

# Remove work dir
rm -rf ${work_dir}

echo "Finished !!"


