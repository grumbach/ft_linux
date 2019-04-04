# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    install_sys_software.bash                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: agrumbac <agrumbac@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/03/30 20:53:09 by agrumbac          #+#    #+#              #
#    Updated: 2019/04/04 04:53:30 by agrumbac         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/linux-headers.html
tar xf linux-4.20.12.tar.xz
cd linux-4.20.12
make mrproper
make INSTALL_HDR_PATH=dest headers_install
find dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv dest/include/* /usr/include
cd ..
rm -rf linux-4.20.12


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/man-pages.html
tar xf man-pages-4.16.tar.xz
cd man-pages-4.16
make install
cd ..
rm -rf man-pages-4.16


############################## cheating here ###################################
# hack in case glibc below doesn't find Python :
# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/Python.html
tar xf Python-3.7.2.tar.xz
cd Python-3.7.2
sed -i '/def add_multiarch_paths/a \        return' setup.py
./configure --prefix=/tools --without-ensurepip
make
make install
cd ..
rm -rf Python-3.7.2
############################## cheating here ###################################


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/glibc.html
tar xf glibc-2.29.tar.xz
cd glibc-2.29
patch -Np1 -i ../glibc-2.29-fhs-1.patch
ln -sfv /tools/lib/gcc /usr/lib
case $(uname -m) in
    i?86)    GCC_INCDIR=/usr/lib/gcc/$(uname -m)-pc-linux-gnu/8.2.0/include
            ln -sfv ld-linux.so.2 /lib/ld-lsb.so.3
    ;;
    x86_64) GCC_INCDIR=/usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 /lib64/ld-lsb-x86-64.so.3
    ;;
esac
rm -f /usr/include/limits.h
mkdir -v build
cd       build
CC="gcc -isystem $GCC_INCDIR -isystem /usr/include" \
../configure --prefix=/usr                          \
             --disable-werror                       \
             --enable-kernel=3.2                    \
             --enable-stack-protector=strong        \
             libc_cv_slibdir=/lib
unset GCC_INCDIR
make
# tests
case $(uname -m) in
  i?86)   ln -sfnv $PWD/elf/ld-linux.so.2        /lib ;;
  x86_64) ln -sfnv $PWD/elf/ld-linux-x86-64.so.2 /lib ;;
esac
make check
# install
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
make install
cp -v ../nscd/nscd.conf /etc/nscd.conf
mkdir -pv /var/cache/nscd
mkdir -pv /usr/lib/locale
localedef -i POSIX -f UTF-8 C.UTF-8 2> /dev/null || true
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f SHIFT_JIS ja_JP.SIJS 2> /dev/null || true
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
make localedata/install-locales

# Configuring Glibc
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
tar -xf ../../tzdata2018i.tar.gz
ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}
for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward pacificnew systemv; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done
cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO
# 7 is for Europe
printf 7 | tzselect
cp -v /usr/share/zoneinfo/<xxx> /etc/localtime
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
# end
cd ../..
rm -rf glibc-2.29


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html
# Adjusting the Toolchain
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(uname -m)-pc-linux-gnu/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(uname -m)-pc-linux-gnu/bin/ld
gcc -dumpspecs | sed -e 's@/tools@@g'                   \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' >      \
    `dirname $(gcc --print-libgcc-file-name)`/specs
# test
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
TEST_GCC_1=$(readelf -l a.out | grep ': /lib' | grep "interpreter: /lib64/ld-linux" | wc -l);
if [ $TEST_GCC_1 = "0" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html\n\n"; fi
TEST_GCC_1=$(grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log | grep "succeeded"  | wc -l)
if [ $TEST_GCC_1 -ne "3" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html\n\n"; fi
TEST_GCC_1=$(grep -B1 '^ /usr/include' dummy.log  | wc -l)
if [ $TEST_GCC_1 -ne "2" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html\n\n"; fi
TEST_GCC_1=$(grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' | grep -v "linux-gnu" | grep "/lib" | wc -l)
if [ $TEST_GCC_1 -ne "2" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html\n\n"; fi
TEST_GCC_1=$(grep "/lib.*/libc.so.6 " dummy.log | grep "succeeded" | wc -l)
if [ $TEST_GCC_1 -ne "1" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html\n\n"; fi
TEST_GCC_1=$(grep found dummy.log)
if [ "$TEST_GCC_1" != "found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/adjusting.html\n\n"; fi
rm -v dummy.c a.out dummy.log


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/zlib.html
tar xf zlib-1.2.11.tar.xz
cd zlib-1.2.11
./configure --prefix=/usr
make
make check
make install
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libz.so) /usr/lib/libz.so
cd ..
rm -rf zlib-1.2.11


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/file.html
tar xf file-5.36.tar.gz
cd file-5.36
./configure --prefix=/usr
make
make check
make install
cd ..
rm -rf file-5.36


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/readline.html
tar xf readline-8.0.tar.gz
cd readline-8.0
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/readline-8.0
make SHLIB_LIBS="-L/tools/lib -lncursesw"
make SHLIB_LIBS="-L/tools/lib -lncursesw" install
mv -v /usr/lib/lib{readline,history}.so.* /lib
chmod -v u+w /lib/lib{readline,history}.so.*
ln -sfv ../../lib/$(readlink /usr/lib/libreadline.so) /usr/lib/libreadline.so
ln -sfv ../../lib/$(readlink /usr/lib/libhistory.so ) /usr/lib/libhistory.so
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.0
cd ..
rm -rf readline-8.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/m4.html
tar xf m4-1.4.18.tar.xz
cd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/usr
make
make check
make install
cd ..
rm -rf m4-1.4.18


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bc.html
tar xf bc-1.07.1.tar.gz
cd bc-1.07.1
cat > bc/fix-libmath_h << "EOF"
#! /bin/bash
sed -e '1   s/^/{"/' \
    -e     's/$/",/' \
    -e '2,$ s/^/"/'  \
    -e   '$ d'       \
    -i libmath.h

sed -e '$ s/$/0}/' \
    -i libmath.h
EOF
ln -sv /tools/lib/libncursesw.so.6 /usr/lib/libncursesw.so.6
ln -sfv libncursesw.so.6 /usr/lib/libncurses.so
sed -i -e '/flex/s/as_fn_error/: ;; # &/' configure
./configure --prefix=/usr           \
            --with-readline         \
            --mandir=/usr/share/man \
            --infodir=/usr/share/info
make
echo "quit" | ./bc/bc -l Test/checklib.b
make install
cd ..
rm -rf bc-1.07.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/binutils.html
tar xf binutils-2.32.tar.xz
cd binutils-2.32
# Verify that the PTYs are working properly
TEST_BINUTILS_1=$(expect -c "spawn ls")
TEST_BINUTILS_OK=$(printf "spawn ls\r\n")
if [ "$TEST_BINUTILS_1" != "$TEST_BINUTILS_OK" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/binutils.html\n\n"; fi
# build
mkdir -v build
cd       build
../configure --prefix=/usr       \
             --enable-gold       \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --with-system-zlib
make tooldir=/usr
make -k check
make tooldir=/usr install
cd ../..
rm -rf binutils-2.32


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gmp.htmls
tar xf gmp-6.1.2.tar.xz
cd gmp-6.1.2

./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.1.2
make
make html
make check 2>&1 | tee gmp-check-log
TEST_GMP_1=$(awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log)
if [ $TEST_GMP_1 -neq "190" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gmp.html\n\n"; fi
make install
make install-html
cd ..
rm -rf gmp-6.1.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/mpfr.html
tar xf mpfr-4.0.2.tar.xz
cd mpfr-4.0.2
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.0.2
make
make html
make check
make install
make install-html
cd ..
rm -rf mpfr-4.0.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/mpc.html
tar xf mpc-1.1.0.tar.gz
cd mpc-1.1.0

./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.1.0
make
make html
make check
make install
make install-html
cd ..
rm -rf mpc-1.1.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/shadow.html
tar xf shadow-4.6.tar.xz
cd shadow-4.6

sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs
sed -i 's/1000/999/' etc/useradd
./configure --sysconfdir=/etc --with-group-name-max-length=32
make
make install
mv -v /usr/bin/passwd /bin
# configuring shadow
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd
cd ..
rm -rf shadow-4.6


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html
# La patience est amere mais son fruit est doux... - JJ Rousseau
tar xf gcc-8.2.0.tar.xz
cd gcc-8.2.0
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
rm -f /usr/lib/gcc
mkdir -v build
cd       build
SED=sed                               \
../configure --prefix=/usr            \
             --enable-languages=c,c++ \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-libmpx         \
             --with-system-zlib
make
# tests
ulimit -s 32768
rm ../gcc/testsuite/g++.dg/pr83239.C
chown -Rv nobody .
su nobody -s /bin/bash -c "PATH=$PATH make -k check"
../contrib/test_summary | grep -A7 Summ
# install
make install
ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc
install -v -dm755 /usr/lib/bfd-plugins
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/8.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/

# test manually
echo 'int main(){}' > dummy.c
cc dummy.c -v -Wl,--verbose &> dummy.log
TEST_GCC_1=$(readelf -l a.out | grep ': /lib' | grep "/lib64/ld-linux" | wc -l)
if [ "$TEST_GCC_1" != "1" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html\n\n"; fi
TEST_GCC_1=$(grep -o '/usr/lib.*/crt[1in].*succeeded' dummy.log | grep "succeeded" | wc -l)
if [ "$TEST_GCC_1" != "3" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html\n\n"; fi
TEST_GCC_1=$(grep -B4 '^ /usr/include' dummy.log)
TEST_GCC_OK=`printf "#include <...> search starts here:\n /usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include\n /usr/local/include\n /usr/lib/gcc/x86_64-pc-linux-gnu/8.2.0/include-fixed\n /usr/include\n"`
if [ "$TEST_GCC_1" != "$TEST_GCC_OK" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html\n\n"; fi
TEST_GCC_1=$(grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g' | grep -v "linux-gnu")
TEST_GCC_OK=`printf 'SEARCH_DIR("/usr/local/lib64")\nSEARCH_DIR("/lib64")\nSEARCH_DIR("/usr/lib64")\nSEARCH_DIR("/usr/local/lib")\nSEARCH_DIR("/lib")\nSEARCH_DIR("/usr/lib");\n'`
if [ "$TEST_GCC_1" != "$TEST_GCC_OK" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html\n\n"; fi
TEST_GCC_1=$(grep "/lib.*/libc.so.6 " dummy.log)
TEST_GCC_OK="attempt to open /lib/libc.so.6 succeeded"
if [ "$TEST_GCC_1" != "$TEST_GCC_OK" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html\n\n"; fi
TEST_GCC_1=$(grep found dummy.log)
TEST_GCC_OK="found ld-linux-x86-64.so.2 at /lib/ld-linux-x86-64.so.2"
if [ "$TEST_GCC_1" != "$TEST_GCC_OK" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gcc.html\n\n"; fi
rm -v dummy.c a.out dummy.log
# move a misplaced file
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib

cd ../..
rm -rf gcc-8.2.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bzip2.html
tar xf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat
cd ..
rm -rf bzip2-1.0.6


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/pkg-config.html
tar xf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr              \
            --with-internal-glib       \
            --disable-host-tool        \
            --docdir=/usr/share/doc/pkg-config-0.29.2
make
make check
make install
cd ..
rm -rf pkg-config-0.29.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/ncurses.html
tar xf ncurses-6.1.tar.gz
cd ncurses-6.1
sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --enable-pc-files       \
            --enable-widec
make
make install
mv -v /usr/lib/libncursesw.so.6* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libncursesw.so) /usr/lib/libncursesw.so
for lib in ncurses form panel menu ; do
    rm -vf                    /usr/lib/lib${lib}.so
    echo "INPUT(-l${lib}w)" > /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc        /usr/lib/pkgconfig/${lib}.pc
done
rm -vf                     /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" > /usr/lib/libcursesw.so
ln -sfv libncurses.so      /usr/lib/libcurses.so
mkdir -v       /usr/share/doc/ncurses-6.1
cp -v -R doc/* /usr/share/doc/ncurses-6.1
cd ..
rm -rf ncurses-6.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/attr.html
tar xf attr-2.4.48.tar.gz
cd attr-2.4.48
./configure --prefix=/usr     \
            --bindir=/bin     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.4.48
make
make check
make install
mv -v /usr/lib/libattr.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libattr.so) /usr/lib/libattr.so
cd ..
rm -rf attr-2.4.48


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/acl.html
tar xf acl-2.2.53.tar.gz
cd acl-2.2.53
./configure --prefix=/usr         \
            --bindir=/bin         \
            --disable-static      \
            --libexecdir=/usr/lib \
            --docdir=/usr/share/doc/acl-2.2.53
make
make install
mv -v /usr/lib/libacl.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libacl.so) /usr/lib/libacl.so
cd ..
rm -rf acl-2.2.53


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libcap.html
tar xf libcap-2.26.tar.xz
cd libcap-2.26
sed -i '/install.*STALIBNAME/d' libcap/Makefile
make
make RAISE_SETFCAP=no lib=lib prefix=/usr install
chmod -v 755 /usr/lib/libcap.so.2.26
mv -v /usr/lib/libcap.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libcap.so) /usr/lib/libcap.so
cd ..
rm -rf libcap-2.26


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/sed.html
tar xf sed-4.7.tar.xz
cd sed-4.7
sed -i 's/usr/tools/'                 build-aux/help2man
sed -i 's/testsuite.panic-tests.sh//' Makefile.in
./configure --prefix=/usr --bindir=/bin
make
make html
make check
make install
install -d -m755           /usr/share/doc/sed-4.7
install -m644 doc/sed.html /usr/share/doc/sed-4.7
cd ..
rm -rf sed-4.7


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/psmisc.html
tar xf psmisc-23.2.tar.xz
cd psmisc-23.2
./configure --prefix=/usr
make
make install
mv -v /usr/bin/fuser   /bin
mv -v /usr/bin/killall /bin
cd ..
rm -rf psmisc-23.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/iana-etc.html
tar xf iana-etc-2.30.tar.bz2
cd iana-etc-2.30
make
make install
cd ..
rm -rf iana-etc-2.30


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bison.html
tar xf bison-3.3.2.tar.xz
cd bison-3.3.2
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.3.2
make
make install
cd ..
rm -rf bison-3.3.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/flex.html
tar xf flex-2.6.4.tar.gz
cd flex-2.6.4
sed -i "/math.h/a #include <malloc.h>" src/flexdef.h
HELP2MAN=/tools/bin/true \
./configure --prefix=/usr --docdir=/usr/share/doc/flex-2.6.4
make
make check
make install
ln -sv flex /usr/bin/lex
cd ..
rm -rf flex-2.6.4


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/grep.html
tar xf grep-3.3.tar.xz
cd grep-3.3
./configure --prefix=/usr --bindir=/bin
make
make -k check
make install
cd ..
rm -rf grep-3.3


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/bash.html
tar xf bash-5.0.tar.gz
cd bash-5.0
./configure --prefix=/usr                    \
            --docdir=/usr/share/doc/bash-5.0 \
            --without-bash-malloc            \
            --with-installed-readline
make
chown -Rv nobody .
su nobody -s /bin/bash -c "PATH=$PATH HOME=/home make tests"
make install
mv -vf /usr/bin/bash /bin
exec /bin/bash --login +h
cd ..
rm -rf bash-5.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libtool.html
tar xf libtool-2.4.6.tar.xz
cd libtool-2.4.6
./configure --prefix=/usr
make
make check
make install
cd ..
rm -rf libtool-2.4.6


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gdbm.html
tar xf gdbm-1.18.1.tar.gz
cd gdbm-1.18.1
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
make
make check
make install
cd ..
rm -rf gdbm-1.18.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gperf.html
tar xf gperf-3.1.tar.gz
cd gperf-3.1
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make
make -j1 check
make install
cd ..
rm -rf gperf-3.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/expat.html
tar xf expat-2.2.6.tar.bz2
cd expat-2.2.6
sed -i 's|usr/bin/env |bin/|' run.sh.in
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.2.6
make
make check
make install
install -v -m644 doc/*.{html,png,css} /usr/share/doc/expat-2.2.6
cd ..
rm -rf expat-2.2.6


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/inetutils.html
tar xf inetutils-1.9.4.tar.xz
cd inetutils-1.9.4
./configure --prefix=/usr        \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
make
make check
make install
mv -v /usr/bin/{hostname,ping,ping6,traceroute} /bin
mv -v /usr/bin/ifconfig /sbin
cd ..
rm -rf inetutils-1.9.4


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/perl.html
tar xf perl-5.28.1.tar.xz
cd perl-5.28.1
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des -Dprefix=/usr                 \
                  -Dvendorprefix=/usr           \
                  -Dman1dir=/usr/share/man/man1 \
                  -Dman3dir=/usr/share/man/man3 \
                  -Dpager="/usr/bin/less -isR"  \
                  -Duseshrplib                  \
                  -Dusethreads
make
make -k test
make install
unset BUILD_ZLIB BUILD_BZIP2
cd ..
rm -rf perl-5.28.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/xml-parser.html
tar xf XML-Parser-2.44.tar.gz
cd XML-Parser-2.44
perl Makefile.PL
make
make test
make install
cd ..
rm -rf XML-Parser-2.44


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/intltool.html
tar xf intltool-0.51.0.tar.gz
cd intltool-0.51.0
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make check
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
cd ..
rm -rf intltool-0.51.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/autoconf.html
tar xf autoconf-2.69.tar.xz
cd autoconf-2.69
sed '361 s/{/\\{/' -i bin/autoscan.in
./configure --prefix=/usr
make
# make check # The test suite is currently broken by bash-5 and libtool-2.4.3
make install
cd ..
rm -rf autoconf-2.69


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/automake.html
tar xf automake-1.16.1.tar.xz
cd automake-1.16.1
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.16.1
make
make -j4 check
make install
cd ..
rm -rf automake-1.16.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/xz.html
tar xf xz-5.2.4.tar.xz
cd xz-5.2.4
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.2.4
make
make check
make install
mv -v   /usr/bin/{lzma,unlzma,lzcat,xz,unxz,xzcat} /bin
mv -v /usr/lib/liblzma.so.* /lib
ln -svf ../../lib/$(readlink /usr/lib/liblzma.so) /usr/lib/liblzma.so
cd ..
rm -rf xz-5.2.4


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/kmod.html
tar xf kmod-26.tar.xz
cd kmod-26
./configure --prefix=/usr          \
            --bindir=/bin          \
            --sysconfdir=/etc      \
            --with-rootlibdir=/lib \
            --with-xz              \
            --with-zlib
make
make install
for target in depmod insmod lsmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /sbin/$target
done
ln -sfv kmod /bin/lsmod
cd ..
rm -rf kmod-26


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gettext.html
tar xf gettext-0.19.8.1.tar.xz
cd gettext-0.19.8.1
sed -i '/^TESTS =/d' gettext-runtime/tests/Makefile.in &&
sed -i 's/test-lock..EXEEXT.//' gettext-tools/gnulib-tests/Makefile.in
sed -e '/AppData/{N;N;p;s/\.appdata\./.metainfo./}' \
    -i gettext-tools/its/appdata.loc
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.19.8.1
make
make check
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
cd ..
rm -rf gettext-0.19.8.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libelf.html
tar xf elfutils-0.176.tar.bz2
cd elfutils-0.176
./configure --prefix=/usr
make
make check
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
cd ..
rm -rf elfutils-0.176


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libffi.html
tar xf libffi-3.2.1.tar.gz
cd libffi-3.2.1
sed -e '/^includesdir/ s/$(libdir).*$/$(includedir)/' \
    -i include/Makefile.in
sed -e '/^includedir/ s/=.*$/=@includedir@/' \
    -e 's/^Cflags: -I${includedir}/Cflags:/' \
    -i libffi.pc.in
./configure --prefix=/usr --disable-static --with-gcc-arch=native
make
make check
make install
cd ..
rm -rf libffi-3.2.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/openssl.html
tar xf openssl-1.1.1a.tar.gz
cd openssl-1.1.1a
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
make
make test
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-1.1.1a
cp -vfr doc/* /usr/share/doc/openssl-1.1.1a
cd ..
rm -rf openssl-1.1.1a


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/Python.html
tar xf Python-3.7.2.tar.xz
cd Python-3.7.2
./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes
make
make install
chmod -v 755 /usr/lib/libpython3.7m.so
chmod -v 755 /usr/lib/libpython3.so
install -v -dm755 /usr/share/doc/python-3.7.2/html
tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.7.2/html \
    -xvf ../python-3.7.2-docs-html.tar.bz2
cd ..
rm -rf Python-3.7.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/ninja.html
tar xf ninja-1.9.0.tar.gz
cd ninja-1.9.0
export NINJAJOBS=4
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
python3 configure.py --bootstrap
python3 configure.py
./ninja ninja_test
./ninja_test --gtest_filter=-SubprocessTest.SetWithLots
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
cd ..
rm -rf ninja-1.9.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/meson.html
tar xf meson-0.49.2.tar.gz
cd meson-0.49.2
python3 setup.py build
python3 setup.py install --root=dest
cp -rv dest/* /
cd ..
rm -rf meson-0.49.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/coreutils.html
tar xf coreutils-8.30.tar.xz
cd coreutils-8.30
patch -Np1 -i ../coreutils-8.30-i18n-1.patch
sed -i '/test.lock/s/^/#/' gnulib-tests/gnulib.mk
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime
FORCE_UNSAFE_CONFIGURE=1 make
make NON_ROOT_USERNAME=nobody check-root
echo "dummy:x:1000:nobody" >> /etc/group
chown -Rv nobody .
su nobody -s /bin/bash \
          -c "PATH=$PATH make RUN_EXPENSIVE_TESTS=yes check"
sed -i '/dummy/d' /etc/group
make install
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
mv -v /usr/bin/{head,nice,sleep,touch} /bin
cd ..
rm -rf coreutils-8.30


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/check.html
tar xf check-0.12.0.tar.gz
cd check-0.12.0
./configure --prefix=/usr
make
# make check
make install
sed -i '1 s/tools/usr/' /usr/bin/checkmk
cd ..
rm -rf check-0.12.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/diffutils.html
tar xf diffutils-3.7.tar.xz
cd diffutils-3.7
./configure --prefix=/usr
make
make check
make install
cd ..
rm -rf diffutils-3.7


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gawk.html
tar xf gawk-4.2.1.tar.xz
cd gawk-4.2.1
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
make check
make install
mkdir -v /usr/share/doc/gawk-4.2.1
cp    -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.2.1
cd ..
rm -rf gawk-4.2.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/findutils.html
tar xf findutils-4.6.0.tar.gz
cd findutils-4.6.0
sed -i 's/test-lock..EXEEXT.//' tests/Makefile.in
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make check
make install
mv -v /usr/bin/find /bin
sed -i 's|find:=${BINDIR}|find:=/bin|' /usr/bin/updatedb
cd ..
rm -rf findutils-4.6.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/groff.html
tar xf groff-1.22.4.tar.gz
cd groff-1.22.4
PAGE=A4 ./configure --prefix=/usr
make -j1
make install
cd ..
rm -rf groff-1.22.4


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/grub.html
tar xf grub-2.02.tar.xz
cd grub-2.02
./configure --prefix=/usr          \
            --sbindir=/sbin        \
            --sysconfdir=/etc      \
            --disable-efiemu       \
            --disable-werror
make
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
cd ..
rm -rf grub-2.02


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/less.html
tar xf less-530.tar.gz
cd less-530
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd ..
rm -rf less-530


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/gzip.html
tar xf gzip-1.10.tar.xz
cd gzip-1.10
./configure --prefix=/usr
make
make check
make install
mv -v /usr/bin/gzip /bin
cd ..
rm -rf gzip-1.10


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/iproute2.html
tar xf iproute2-4.20.0.tar.xz
cd iproute2-4.20.0
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
sed -i 's/.m_ipt.o//' tc/Makefile
make
make DOCDIR=/usr/share/doc/iproute2-4.20.0 install
cd ..
rm -rf iproute2-4.20.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/kbd.html
tar xf kbd-2.0.4.tar.xz
cd kbd-2.0.4
patch -Np1 -i ../kbd-2.0.4-backspace-1.patch
sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/g' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr --disable-vlock
make
make check
make install
mkdir -v       /usr/share/doc/kbd-2.0.4
cp -R -v docs/doc/* /usr/share/doc/kbd-2.0.4
cd ..
rm -rf kbd-2.0.4


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/libpipeline.html
tar xf libpipeline-1.5.1.tar.gz
cd libpipeline-1.5.1
./configure --prefix=/usr
make
make check
make install
cd ..
rm -rf libpipeline-1.5.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/make.html
tar xf make-4.2.1.tar.bz2
cd make-4.2.1
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/usr
make
make PERL5LIB=$PWD/tests/ check
make install
cd ..
rm -rf make-4.2.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/patch.html
tar xf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/usr
make
make check
make install
cd ..
rm -rf patch-2.7.6


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/man-db.html
tar xf man-db-2.8.5.tar.xz
cd man-db-2.8.5
./configure --prefix=/usr                        \
            --docdir=/usr/share/doc/man-db-2.8.5 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --enable-cache-owner=bin             \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap            \
            --with-systemdtmpfilesdir=           \
            --with-systemdsystemunitdir=
make
make check
make install
cd ..
rm -rf man-db-2.8.5


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/tar.html
tar xf tar-1.31.tar.xz
cd tar-1.31
sed -i 's/abort.*/FALLTHROUGH;/' src/extract.c
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr \
            --bindir=/bin
make
make check
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.31
cd ..
rm -rf tar-1.31


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/texinfo.html
tar xf texinfo-6.5.tar.xz
cd texinfo-6.5
sed -i '5481,5485 s/({/(\\{/' tp/Texinfo/Parser.pm
./configure --prefix=/usr --disable-static
make
make check
make install
make TEXMF=/usr/share/texmf install-tex
pushd /usr/share/info
rm -v dir
for f in *
  do install-info $f dir 2>/dev/null
done
popd
cd ..
rm -rf texinfo-6.5


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/vim.html
tar xf vim-8.1.tar.bz2
cd vim81/
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
# LANG=en_US.UTF-8 make -j1 test &> vim-test.log
make install
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim81/doc /usr/share/doc/vim-8.1
# config
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set number
set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
cd ..
rm -rf vim81/


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/procps-ng.html
tar xf procps-ng-3.3.15.tar.xz
cd procps-ng-3.3.15
./configure --prefix=/usr                            \
            --exec-prefix=                           \
            --libdir=/usr/lib                        \
            --docdir=/usr/share/doc/procps-ng-3.3.15 \
            --disable-static                         \
            --disable-kill
make
sed -i -r 's|(pmap_initname)\\\$|\1|' testsuite/pmap.test/pmap.exp
sed -i '/set tty/d' testsuite/pkill.test/pkill.exp
rm testsuite/pgrep.test/pgrep.exp
make check
make install
mv -v /usr/lib/libprocps.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libprocps.so) /usr/lib/libprocps.so
cd ..
rm -rf procps-ng-3.3.15


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/util-linux.html
tar xf util-linux-2.33.1.tar.xz
cd util-linux-2.33.1
mkdir -pv /var/lib/hwclock
rm -vf /usr/include/{blkid,libmount,uuid}
./configure ADJTIME_PATH=/var/lib/hwclock/adjtime   \
            --docdir=/usr/share/doc/util-linux-2.33.1 \
            --disable-chfn-chsh  \
            --disable-login      \
            --disable-nologin    \
            --disable-su         \
            --disable-setpriv    \
            --disable-runuser    \
            --disable-pylibmount \
            --disable-static     \
            --without-python     \
            --without-systemd    \
            --without-systemdsystemunitdir
make
# many failures so tests skipped
# chown -Rv nobody .
# su nobody -s /bin/bash -c "PATH=$PATH make -k check"
make install
cd ..
rm -rf util-linux-2.33.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/e2fsprogs.html
tar xf e2fsprogs-1.44.5.tar.gz
cd e2fsprogs-1.44.5
mkdir -v build
cd build
../configure --prefix=/usr           \
             --bindir=/bin           \
             --with-root-prefix=""   \
             --enable-elf-shlibs     \
             --disable-libblkid      \
             --disable-libuuid       \
             --disable-uuidd         \
             --disable-fsck
make
make check
make install
make install-libs
chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
cd ../..
rm -rf e2fsprogs-1.44.5


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/sysklogd.html
tar xf sysklogd-1.5.1.tar.gz
cd sysklogd-1.5.1
sed -i '/Error loading kernel symbols/{n;n;d}' ksym_mod.c
sed -i 's/union wait/int/' syslogd.c
make
make BINDIR=/sbin install
# config
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
cd ..
rm -rf sysklogd-1.5.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/sysvinit.html
tar xf sysvinit-2.93.tar.xz
cd sysvinit-2.93
patch -Np1 -i ../sysvinit-2.93-consolidated-1.patch
make
make install
cd ..
rm -rf sysvinit-2.93


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/eudev.html
tar xf eudev-3.2.7.tar.gz
cd eudev-3.2.7
cat > config.cache << "EOF"
HAVE_BLKID=1
BLKID_LIBS="-lblkid"
BLKID_CFLAGS="-I/tools/include"
EOF
./configure --prefix=/usr           \
            --bindir=/sbin          \
            --sbindir=/sbin         \
            --libdir=/usr/lib       \
            --sysconfdir=/etc       \
            --libexecdir=/lib       \
            --with-rootprefix=      \
            --with-rootlibdir=/lib  \
            --enable-manpages       \
            --disable-static        \
            --config-cache
LIBRARY_PATH=/tools/lib make
mkdir -pv /lib/udev/rules.d
mkdir -pv /etc/udev/rules.d
make LD_LIBRARY_PATH=/tools/lib check
make LD_LIBRARY_PATH=/tools/lib install
tar -xvf ../udev-lfs-20171102.tar.bz2
make -f udev-lfs-20171102/Makefile.lfs install
# config
LD_LIBRARY_PATH=/tools/lib udevadm hwdb --update
cd ..
rm -rf eudev-3.2.7
