# **************************************************************************** #
#                                                                              #
#                                                         :::      ::::::::    #
#    install_sys_software.bash                          :+:      :+:    :+:    #
#                                                     +:+ +:+         +:+      #
#    By: agrumbac <agrumbac@student.42.fr>          +#+  +:+       +#+         #
#                                                 +#+#+#+#+#+   +#+            #
#    Created: 2019/03/30 20:53:09 by agrumbac          #+#    #+#              #
#    Updated: 2019/03/30 20:57:26 by agrumbac         ###   ########.fr        #
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


# http://www.linuxfromscratch.org/lfs/view/stable/chapter06/glibc.html
