# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    install_additional_software.bash                   :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: agrumbac <agrumbac@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/04/05 10:08:55 by agrumbac          #+#    #+#              #
#    Updated: 2019/04/09 23:16:28 by agrumbac         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #


# http://www.linuxfromscratch.org/blfs/view/8.4/basicnet/wget.html
tar xf wget-1.20.1.tar.gz
cd wget-1.20.1
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl &&
make
make install
cd ..
rm -rf wget-1.20.1


# http://www.linuxfromscratch.org/blfs/view/8.4/general/gdb.html
tar xf gdb-8.2.1.tar.xz
cd gdb-8.2.1
./configure --prefix=/usr --with-system-readline &&
make
make -C gdb/doc doxy
# skipping tests (66 SBU)
# pushd gdb/testsuite &&
# make  site.exp      &&
# echo  "set gdb_test_timeout 120" >> site.exp &&
# runtest
# popd
make -C gdb install
install -d /usr/share/doc/gdb-8.2.1 &&
rm -rf gdb/doc/doxy/xml &&
cp -Rv gdb/doc/doxy /usr/share/doc/gdb-8.2.1
cd ..
rm -rf gdb-8.2.1


# http://www.linuxfromscratch.org/blfs/view/8.4/postlfs/openssh.html
tar xf openssh-7.9p1.tar.gz
cd openssh-7.9p1
install  -v -m700 -d /var/lib/sshd &&
chown    -v root:sys /var/lib/sshd &&
groupadd -g 50 sshd        &&
useradd  -c 'sshd PrivSep' \
         -d /var/lib/sshd  \
         -g sshd           \
         -s /bin/false     \
         -u 50 sshd
wget http://www.linuxfromscratch.org/patches/blfs/8.4/openssh-7.9p1-security_fix-1.patch
patch -Np1 -i openssh-7.9p1-security_fix-1.patch &&
./configure --prefix=/usr                     \
     --sysconfdir=/etc/ssh             \
     --with-md5-passwords              \
     --with-privsep-path=/var/lib/sshd &&
make
make install &&
install -v -m755    contrib/ssh-copy-id /usr/bin     &&

install -v -m644    contrib/ssh-copy-id.1 \
                    /usr/share/man/man1              &&
install -v -m755 -d /usr/share/doc/openssh-7.9p1     &&
install -v -m644    INSTALL LICENCE OVERVIEW README* \
                    /usr/share/doc/openssh-7.9p1
# boot scripts
wget http://anduin.linuxfromscratch.org/BLFS/blfs-bootscripts/blfs-bootscripts-20180105.tar.xz
tar xf blfs-bootscripts-20180105.tar.xz
cd blfs-bootscripts-20180105
make install-sshd
cd ../..
rm -rf openssh-7.9p1


# http://www.linuxfromscratch.org/blfs/view/svn/basicnet/curl.html
tar xf curl-7.64.1.tar.xz
cd curl-7.64.1
./configure --prefix=/usr                           \
            --disable-static                        \
            --enable-threaded-resolver              \
            --with-ca-path=/etc/ssl/certs &&
make
make install &&

rm -rf docs/examples/.deps &&

find docs \( -name Makefile\* -o -name \*.1 -o -name \*.3 \) -exec rm {} \; &&

install -v -d -m755 /usr/share/doc/curl-7.64.1 &&
cp -v -R docs/*     /usr/share/doc/curl-7.64.1
cd ..
rm -rf curl-7.64.1


# http://www.linuxfromscratch.org/blfs/view/svn/general/git.html
tar xf git-2.21.0.tar.xz
cd git-2.21.0
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig &&
make
make install
# install docs
wget https://www.kernel.org/pub/software/scm/git/git-manpages-2.21.0.tar.xz
wget https://www.kernel.org/pub/software/scm/git/git-htmldocs-2.21.0.tar.xz
tar -xf git-manpages-2.21.0.tar.xz \
    -C /usr/share/man --no-same-owner --no-overwrite-dir
mkdir -vp   /usr/share/doc/git-2.21.0 &&
tar   -xf   git-htmldocs-2.21.0.tar.xz \
      -C    /usr/share/doc/git-2.21.0 --no-same-owner --no-overwrite-dir &&
find        /usr/share/doc/git-2.21.0 -type d -exec chmod 755 {} \; &&
find        /usr/share/doc/git-2.21.0 -type f -exec chmod 644 {} \;
mkdir -vp /usr/share/doc/git-2.21.0/man-pages/{html,text}         &&
mv        /usr/share/doc/git-2.21.0/{git*.txt,man-pages/text}     &&
mv        /usr/share/doc/git-2.21.0/{git*.,index.,man-pages/}html &&

mkdir -vp /usr/share/doc/git-2.21.0/technical/{html,text}         &&
mv        /usr/share/doc/git-2.21.0/technical/{*.txt,text}        &&
mv        /usr/share/doc/git-2.21.0/technical/{*.,}html           &&

mkdir -vp /usr/share/doc/git-2.21.0/howto/{html,text}             &&
mv        /usr/share/doc/git-2.21.0/howto/{*.txt,text}            &&
mv        /usr/share/doc/git-2.21.0/howto/{*.,}html               &&

sed -i '/^<a href=/s|howto/|&html/|' /usr/share/doc/git-2.21.0/howto-index.html &&
sed -i '/^\* link:/s|howto/|&html/|' /usr/share/doc/git-2.21.0/howto-index.txt
cd ..
rm -rf git-2.21.0


# https://github.com/mtoyoda/sl
git clone https://github.com/mtoyoda/sl
cd sl
make
mv sl /bin/
cd ..
rm -rf sl
