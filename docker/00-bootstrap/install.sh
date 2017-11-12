#!/bin/sh

cd /tmp

# move and cleanup libraries
tar -xf amd64-linux-musl.tar.xz --directory / && \
  rm /tmp/install.sh && \
  rm /tmp/amd64-linux-musl.tar.xz

# fix links necessary for the dynamic loader to work
ln -sf /usr/local/lib/libc.so /usr/local/lib/ld-musl-x86_64.so.1
mkdir -p /lib
cp -P /usr/local/lib/ld-musl-x86_64.so.1 /lib/

cd /usr/local/bin

# create a bunch of handful aliases
for f in amd64-linux-musl-*; do
  target=$(echo $f | sed 's/amd64-linux-musl-//g')
  if [ ! -f $target ]; then
    ln -s $f $target
  fi
done

# create the image.dist file using file installed in /usr/local and the link
# created in /lib
find /usr/local | sed 's/\.\///' > /image.dist
echo '/lib' >> /image.dist
