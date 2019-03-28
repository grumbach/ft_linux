# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    install_software.bash                              :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: agrumbac <agrumbac@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/03/26 18:24:02 by agrumbac          #+#    #+#              #
#    Updated: 2019/03/28 18:51:44 by agrumbac         ###   ########.fr        #
#                                                                              #
# **************************************************************************** #


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/binutils-pass1.html
tar xf binutils-2.32.tar*
cd binutils-2.32
mkdir -v build
cd       build
../configure --prefix=/tools            \
	--with-sysroot=$LFS        \
	--with-lib-path=/tools/lib \
	--target=$LFS_TGT          \
	--disable-nls              \
	--disable-werror
make
case $(uname -m) in
	x86_64) mkdir -v /tools/lib && ln -sv lib /tools/lib64 ;;
esac
make install
cd ../..
rm -rf binutils-2.32


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/gcc-pass1.html
tar xf gcc-8.2.0.tar*
cd gcc-8.2.0
tar -xf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc
for file in gcc/config/{linux,i386/linux{,64}}.h
do
	cp -uv $file{,.orig}
	sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
		-e 's@/usr@/tools@g' $file.orig > $file
	echo '
	#undef STANDARD_STARTFILE_PREFIX_1
	#undef STANDARD_STARTFILE_PREFIX_2
	#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
	#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
	touch $file.orig
done
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
 ;;
esac
mkdir -v build
cd       build
../configure                                       \
	--target=$LFS_TGT                              \
	--prefix=/tools                                \
	--with-glibc-version=2.11                      \
	--with-sysroot=$LFS                            \
	--with-newlib                                  \
	--without-headers                              \
	--with-local-prefix=/tools                     \
	--with-native-system-header-dir=/tools/include \
	--disable-nls                                  \
	--disable-shared                               \
	--disable-multilib                             \
	--disable-decimal-float                        \
	--disable-threads                              \
	--disable-libatomic                            \
	--disable-libgomp                              \
	--disable-libmpx                               \
	--disable-libquadmath                          \
	--disable-libssp                               \
	--disable-libvtv                               \
	--disable-libstdcxx                            \
	--enable-languages=c,c++
make
make install
cd ../..
rm -rf gcc-8.2.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/linux-headers.html
tar xf linux-4.20.12.tar*
cd linux-4.20.12
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd ..
rm -rf linux-4.20.12


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/glibc.html
tar xf glibc-2.29.tar*
cd glibc-2.29
mkdir -v build
cd       build
../configure                             \
	--prefix=/tools                    \
	--host=$LFS_TGT                    \
	--build=$(../scripts/config.guess) \
	--enable-kernel=3.2                \
	--with-headers=/tools/include
make
make install
# check gcc install
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
TEST_GCC_1=$(readelf -l a.out | grep ': /tools' | grep "/tools/lib" | wc -l);
if [ $TEST_GCC_1 = "0" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter05/glibc.html\n\n"; fi
rm -v dummy.c a.out
cd ../..
rm -rf glibc-2.29


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/gcc-libstdc++.html
tar xf gcc-8.2.0.tar*
cd gcc-8.2.0
mkdir -v build
cd       build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/8.2.0
make
make install
cd ../..
rm -rf gcc-8.2.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/binutils-pass2.html
tar xf binutils-2.32.tar*
cd binutils-2.32
mkdir -v build
cd       build
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot
make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd ../..
rm -rf binutils-2.32


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/gcc-pass2.html
tar xf gcc-8.2.0.tar*
cd gcc-8.2.0
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
for file in gcc/config/{linux,i386/linux{,64}}.h
do
cp -uv $file{,.orig}
sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
    -e 's@/usr@/tools@g' $file.orig > $file
echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
touch $file.orig
done
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \
        -i.orig gcc/config/i386/t-linux64
  ;;
esac
tar -xf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -xf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -xf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc
mkdir -v build
cd       build
CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../configure                                       \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp
make
make install
ln -sv gcc /tools/bin/cc
# check gcc install
echo 'int main(){}' > dummy.c
$LFS_TGT-gcc dummy.c
TEST_GCC_1=$(readelf -l a.out | grep ': /tools' | grep "/tools/lib" | wc -l);
if [ $TEST_GCC_1 = "0" ]; then printf "\n\n\e[31m ERROR ABOVE check test at http://www.linuxfromscratch.org/lfs/view/stable/chapter05/glibc.html\n\n"; fi
rm -v dummy.c a.out
cd ../..
rm -rf gcc-8.2.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/tcl.html
tar xf tcl8.6.9-src.tar.gz
cd tcl8.6.9
cd unix
./configure --prefix=/tools
make
TZ=UTC make test
make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd ../..
rm -rf tcl8.6.9


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/expect.html
tar xf expect5.45.4.tar.gz
cd expect5.45.4
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
make
make test
make SCRIPTS="" install
cd ..
rm -rf expect5.45.4


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/dejagnu.html
tar xf dejagnu-1.6.2.tar.gz
cd dejagnu-1.6.2
./configure --prefix=/tools
make install
make check
cd ..
rm -rf dejagnu-1.6.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/m4.html
tar xf m4-1.4.18.tar.xz
cd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/tools
make
make check
make install
cd ..
rm -rf m4-1.4.18


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/ncurses.html
tar xf ncurses-6.1.tar.gz
cd ncurses-6.1
sed -i s/mawk// configure
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make
make install
ln -s libncursesw.so /tools/lib/libncurses.so
cd ..
rm -rf ncurses-6.1


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/bash.html
tar xf bash-5.0.tar.gz
cd bash-5.0
./configure --prefix=/tools --without-bash-malloc
make
make tests
make install
ln -sv bash /tools/bin/sh
cd ..
rm -rf bash-5.0


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/bison.htmls
tar xf bison-3.3.2.tar.xz
cd bison-3.3.2
./configure --prefix=/tools
make
make check
make install
cd ..
rm -rf bison-3.3.2


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/bzip2.html
tar xf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make
make PREFIX=/tools install
cd ..
rm -rf bzip2-1.0.6


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/coreutils.html
tar xf coreutils-8.30.tar.xz
cd coreutils-8.30
./configure --prefix=/tools --enable-install-program=hostname
make
make RUN_EXPENSIVE_TESTS=yes check
make install
cd ..
rm -rf coreutils-8.30


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/diffutils.html
tar xf diffutils-3.7.tar.xz
cd diffutils-3.7
./configure --prefix=/tools
make
make check
make install
cd ..
rm -rf diffutils-3.7


# http://www.linuxfromscratch.org/lfs/view/stable/chapter05/file.html
