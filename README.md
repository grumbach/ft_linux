# ft_linux
Making my own linux distribution ([LFS](http://www.linuxfromscratch.org/lfs/view/stable/))

# Getting Ready

## VM creation

* Create Linux 4.xx VM
* Create a 10GB vdi
* Boot on a Linux live CD (used ubuntu) with the mounted vdi

## Partition with Gparted

| Name   | Partition | Filesystem | Size     |
|--------|-----------|------------|----------|
| boot   | /dev/sda1 | ext2       | 100Mb    |
| swap   | /dev/sda2 | linux-swap | 2Gb      |
| root   | /dev/sda3 | ext4       | 10Gb     |

## `ssh` for convenience

```bash
sudo su
apt-get update
apt-get upgrade -y
apt-get install -y openssh-server
ip address | grep inet
```

# Preparations

```bash
# become The One
sudo su

# mount root partition
export LFS=/mnt/lfs
mkdir -v $LFS
mount -v -t ext4 /dev/sda3 $LFS

# mount swap
swapoff /dev/sda2
mkswap /dev/sda2
swapon /dev/sda2

# create source dir
mkdir -v $LFS/sources
chmod -v a+wt $LFS/sources

# fill it with an ocean of tarballs
apt install -y curl
curl http://www.linuxfromscratch.org/lfs/view/stable/wget-list > wget-list
wget --input-file=wget-list --continue --directory-prefix=$LFS/sources

# check integrity
curl http://www.linuxfromscratch.org/lfs/view/stable/md5sums > $LFS/sources/md5sums
pushd $LFS/sources
md5sum -c md5sums
popd

# create a tools dir
mkdir -v $LFS/tools
ln -sv $LFS/tools /

# create user lfs
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs

# choose a password ("toor")
printf 'toor\ntoor\n' | passwd lfs

# give lfs some dirs
chown -v lfs $LFS/tools
chown -v lfs $LFS/sources

# login as lfs
su - lfs

# make life easy
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/tools/bin:/bin:/usr/bin
export LFS LC_ALL LFS_TGT PATH
EOF
source ~/.bash_profile
export MAKEFLAGS='-j 2'

# get back to root
exec <&-

# make /bin/sh -> bash
echo "dash dash/sh boolean false" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
# make /bin/awk -> gawk
apt-get install -y gawk
# make /usr/bin/yacc -> bison
apt-get install -y bison
# install gcc and everything else
apt-get install -y build-essential

# check everything (WARNING unsafe: executing downloaded code)
curl http://www.linuxfromscratch.org/lfs/view/stable/chapter02/hostreqs.html | grep -A53 "# Simple script to list version numbers of critical development tools" | sed 's:</code>::g' | sed 's:&gt;:>:g' | sed 's:&lt;:<:g' | sed 's:&amp;:\&:g' | sed 's:failed:not OK:g' > version-check.sh
bash version-check.sh | grep not
# make sure no errors appear above
```

# Constructing a Temporary System

```bash
# get back to lfs
su - lfs

export LFS=/mnt/lfs
export MAKEFLAGS='-j 2'
cd $LFS/sources/
```

Install software with [install_software.bash](install_software.bash)

```bash
# make some room
strip --strip-debug /tools/lib/*
/usr/bin/strip --strip-unneeded /tools/{,s}bin/*
rm -rf /tools/{,share}/{info,man,doc}
find /tools/{lib,libexec} -name \*.la -delete

# get back to root
exec <&-
export LFS=/mnt/lfs

# change ownership
chown -R root:root $LFS/tools
```

# Building the LFS System

```bash
# if not already, become The One
sudo su
export LFS=/mnt/lfs

# create dirs for the system
mkdir -pv $LFS/{dev,proc,sys,run}

# create initial device node
mknod -m 600 $LFS/dev/console c 5 1
mknod -m 666 $LFS/dev/null c 1 3

```

## Entering the chroot

```bash
# mount everything before entering the chroot environment
mount -v --bind /dev $LFS/dev
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi

# enter the chroot environment
chroot "$LFS" /tools/bin/env -i \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin:/tools/bin \
    /tools/bin/bash --login +h
```

## The chroot environment

```bash
# creating directories
mkdir -pv /{bin,boot,etc/{opt,sysconfig},home,lib/firmware,mnt,opt}
mkdir -pv /{media/{floppy,cdrom},sbin,srv,var}
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
mkdir -pv /usr/{,local/}{bin,include,lib,sbin,src}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -v  /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -v  /usr/libexec
mkdir -pv /usr/{,local/}share/man/man{1..8}

case $(uname -m) in
 x86_64) mkdir -v /lib64 ;;
esac

mkdir -v /var/{log,mail,spool}
ln -sv /run /var/run
ln -sv /run/lock /var/lock
mkdir -pv /var/{opt,cache,lib/{color,misc,locate},local}

# creating symlinks
ln -sv /tools/bin/{bash,cat,chmod,dd,echo,ln,mkdir,pwd,rm,stty,touch} /bin
ln -sv /tools/bin/{env,install,perl,printf}         /usr/bin
ln -sv /tools/lib/libgcc_s.so{,.1}                  /usr/lib
ln -sv /tools/lib/libstdc++.{a,so{,.6}}             /usr/lib

install -vdm755 /usr/lib/pkgconfig

ln -sv bash /bin/sh

ln -sv /proc/self/mounts /etc/mtab

# create /etc/passwd
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/bin/false
daemon:x:6:6:Daemon User:/dev/null:/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/var/run/dbus:/bin/false
nobody:x:99:99:Unprivileged User:/dev/null:/bin/false
EOF

# create /etc/group
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
wheel:x:97:
nogroup:x:99:
users:x:999:
EOF

# login in bash
exec /tools/bin/bash --login +h

# initialize log files
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp

# get back to the /source dir
cd /sources/
```

## Installing Basic System Software

Install basic system software with [install_sys_software.bash](install_sys_software.bash)

```bash
# change root password
passwd root
```

## Cleanup

```bash
# stripping was voluntarily skipped, to do it visit :
# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/strippingagain.html

# cleanup
rm -rf /tmp/*

# reenter chroot env with the new chroot
logout
chroot "$LFS" /usr/bin/env -i          \
    HOME=/root TERM="$TERM"            \
    PS1='(lfs chroot) \u:\w\$ '        \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    /bin/bash --login

# remove remaining static libs
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libz.a

# remove unneeded .la files
find /usr/lib /usr/libexec -name \*.la -delete
```

## System configuration

```bash
# install LFS-Bootscripts
tar xf lfs-bootscripts-20180820.tar.bz2
cd lfs-bootscripts-20180820
make install
cd ..
rm -rf lfs-bootscripts-20180820

# creating custom udev rules
bash /lib/udev/init-net-rules.sh

# gather network info (set this according to your network)
NETW_NAME=$(cat /etc/udev/rules.d/70-persistent-net.rules | grep ACTION | awk -F "NAME=" '{print $2}' | sed 's/"//g' | head -1)
NETW_IP=$(ifconfig | grep -A2 $NETW_NAME | grep inet | awk -F ":" '{print $2}' | awk -F " " '{print $1}')
NETW_GATEWAY=$(echo $NETW_IP | awk -F "." '{print $1"."$2".254.254"}')
NETW_BCAST=$(echo $NETW_IP | awk -F "." '{print $1"."$2".255.255"}')
NETW_PREFIX="16"

# set up eth0 device with a static IP address
cd /etc/sysconfig/
printf "ONBOOT=yes\n\
IFACE=$NETW_NAME\n\
SERVICE=ipv4-static\n\
IP=$NETW_IP\n\
GATEWAY=$NETW_GATEWAY\n\
PREFIX=$NETW_PREFIX\n\
BROADCAST=$NETW_BCAST\n\
"> ifconfig.$NETW_NAME

# set up dns
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

nameserver 1.1.1.1
nameserver 1.0.0.1

# End /etc/resolv.conf
EOF

# set hostname
HOST_NAME="agrumbac"
echo $HOST_NAME > /etc/hostname

# set up /etc/hosts
printf "\
# Begin /etc/hosts\n\
\n\
127.0.0.1 localhost\n\
$NETW_IP $HOST_NAME\n\
::1       localhost ip6-localhost ip6-loopback\n\
ff02::1   ip6-allnodes\n\
ff02::2   ip6-allrouters\n\
\n\
# End /etc/hosts\n\
"> /etc/hosts

# configuring sysvinit
cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

# configuring system clock
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

# set locale
CHOSEN_CHAR_MAP="en_US.iso88591"
LC_ALL=$CHOSEN_CHAR_MAP locale charmap
LC_ALL=$CHOSEN_CHAR_MAP locale language
LC_ALL=$CHOSEN_CHAR_MAP locale charmap
LC_ALL=$CHOSEN_CHAR_MAP locale int_curr_symbol
LC_ALL=$CHOSEN_CHAR_MAP locale int_prefix

# create /etc/profile
printf "\n\
# Begin /etc/profile\n\
\n\
export LANG=$CHOSEN_CHAR_MAP\n\
\n\
# End /etc/profile\n\
" > /etc/profile

# create /etc/inputrc
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

# create /etc/shells
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
```

## Making the LFS System Bootable

```bash
# create the fstab file
printf "\
# Begin /etc/fstab\n\
\n\
# file system  mount-point  type     options             dump  fsck\n\
#                                                              order\n\
\n\
/dev/sda1      /boot        ext2     defaults            0     0\n\
/dev/sda3      /            ext4     defaults            1     1\n\
/dev/sda2      swap         swap     pri=1               0     0\n\
proc           /proc        proc     nosuid,noexec,nodev 0     0\n\
sysfs          /sys         sysfs    nosuid,noexec,nodev 0     0\n\
devpts         /dev/pts     devpts   gid=5,mode=620      0     0\n\
tmpfs          /run         tmpfs    defaults            0     0\n\
devtmpfs       /dev         devtmpfs mode=0755,nosuid    0     0\n\
\n\
# End /etc/fstab\n\
" > /etc/fstab
```

## Installing the Linux Kernel

```bash
cd /sources
tar xf linux-4.20.12.tar.xz
cd linux-4.20.12
make mrproper
make defconfig

# don't do this at home !
# instead of all these **HORRIBLE** sed commands follow these instructions
# http://www.linuxfromscratch.org/lfs/view/stable/chapter08/kernel.html
# make menuconfig
sed -i "s/# CONFIG_EFI_STUB is not set/CONFIG_EFI_STUB=y\n# CONFIG_EFI_MIXED is not set/g" .config
sed -i "s/# CONFIG_EFI_TEST is not set/# CONFIG_EFI_TEST is not set\n# CONFIG_APPLE_PROPERTIES is not set\n# CONFIG_RESET_ATTACK_MITIGATION is not set/g" .config
sed -i 's/CONFIG_UEVENT_HELPER=y/# CONFIG_UEVENT_HELPER is not set/g' .config
sed -i 's:CONFIG_UEVENT_HELPER_PATH="/sbin/hotplug"::g' .config
sed -i 's/CONFIG_SECTION_MISMATCH_WARN_ONLY=y/CONFIG_SECTION_MISMATCH_WARN_ONLY=y\nCONFIG_FRAME_POINTER=y/' .config
sed -i 's/CONFIG_UNWINDER_ORC=y/# CONFIG_UNWINDER_ORC is not set/g' .config
sed -i 's/# CONFIG_UNWINDER_FRAME_POINTER is not set/CONFIG_UNWINDER_FRAME_POINTER=y/g' .config

# takes some time...
make

# install modules
make modules_install

# bind the boot partition as root in host system
exec <&-
sudo su
umount /boot
mount /dev/sda1 /boot
mount --bind /boot /mnt/lfs/boot

# enter chroot again
export LFS=/mnt/lfs
chroot "$LFS" /usr/bin/env -i          \
    HOME=/root TERM="$TERM"            \
    PS1='(lfs chroot) \u:\w\$ '        \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    /bin/bash --login
cd /sources/linux-4.20.12

# copy files to /boot
cp -iv arch/x86/boot/bzImage /boot/vmlinuz-4.20.12-agrumbac
cp -iv System.map /boot/System.map-4.20.12
cp -iv .config /boot/config-4.20.12
install -d /usr/share/doc/linux-4.20.12
cp -r Documentation/* /usr/share/doc/linux-4.20.12

# chown kernel sources to root
cd ..
chown -R 0:0 linux-4.20.12

# configuring linux module load order
install -v -m755 -d /etc/modprobe.d
cat > /etc/modprobe.d/usb.conf << "EOF"
# Begin /etc/modprobe.d/usb.conf

install ohci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i ohci_hcd ; true
install uhci_hcd /sbin/modprobe ehci_hcd ; /sbin/modprobe -i uhci_hcd ; true

# End /etc/modprobe.d/usb.conf
EOF
```

## Set up GRUB

```bash
# set up the boot track
grub-install /dev/sda

# creating the GRUB configuration file
cat > /boot/grub/grub.cfg << "EOF"
# Begin /boot/grub/grub.cfg
set default=0
set timeout=5

insmod ext2
set root=(hd0,1)

menuentry "GNU/Linux, Linux 4.20.12-lfs-8.4" {
        linux   /vmlinuz-4.20.12-agrumbac root=/dev/sda3 ro
}
EOF
```

## (Optional) Install additional software

Install with [install_additional_software.bash](install_additional_software.bash)

## The End

```bash
# create lfs-release file
echo 8.4 > /etc/lfs-release

# create status file
cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="8.4"
DISTRIB_CODENAME="agrumbac"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

# exit the chroot
logout

# unmount everything
umount -v $LFS/dev/pts
umount -v $LFS/dev
umount -v $LFS/run
umount -v $LFS/proc
umount -v $LFS/sys
umount -v $LFS

# reboot
shutdown -r now
```
