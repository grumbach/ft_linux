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

# check everything
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
