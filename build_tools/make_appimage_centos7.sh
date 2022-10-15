#/bin/sh

set -v
set -e

# base system
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*
sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*
yum install -y epel-release
yum update -y
yum install -y wget python3 python3-pip fuse-libs file cmake3 gcc make git
pip3 install sphinx
mkdir -p /usr/local/bin
ln -s /usr/bin/cmake3 /usr/local/bin/cmake
ln -s /usr/bin/ctest3 /usr/local/bin/ctest

# Enforce C99 mode when building pcre2-sys.
# https://stackoverflow.com/questions/78777912/how-can-i-add-a-std-c99-flag-to-cc-when-compiling-using-cargo
# ln -s /usr/bin/c99 /usr/local/bin/cc

# ncurses
wget -O /ncurses.tar.gz https://invisible-island.net/archives/ncurses/ncurses-6.5.tar.gz
mkdir /ncurses
tar xf /ncurses.tar.gz --strip-components=1 -C /ncurses
mkdir /ncurses-prefix
cd /ncurses
env TERMINFO= TERMINFO_DIRS= ./configure --without-shared
make -j$(nproc)
make install.progs DESTDIR=/ncurses-prefix
make install.data DESTDIR=/ncurses-prefix

# rust
curl https://sh.rustup.rs -sSf | sh -s -- -y

# appimage
export FISH_NCURSES_ROOT=/ncurses-prefix/usr
export LC_CTYPE=en_US.UTF-8
# export CC=c99
# export CFLAGS=-std=gnu99
cd /work # should be monted externally
./build_tools/make_appimage.sh
