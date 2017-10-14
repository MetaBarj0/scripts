#!/bin/sh
tar -xf zlib-1.2.11.tar.xz
cd zlib-1.2.11
mkdir build && cd build

CFLAGS='-O3 -s' \
  LDFLAGS='-Wl,-rpath,/usr/local/lib/,-rpath-link,/usr/local/lib/' \
  ../configure --prefix=/tmp/install

# Calculates the optimal job count
JOBS=$(cat /proc/cpuinfo | grep processor | wc -l)

make -j $JOBS && make install