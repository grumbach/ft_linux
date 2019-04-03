# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    install_sys_software.bash                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: agrumbac <agrumbac@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/03/30 20:53:09 by agrumbac          #+#    #+#              #
#    Updated: 2019/04/03 09:18:39 by agrumbac         ###   ########.fr        #
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
