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
