#!/bin/sh
set -ex

export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"

./configure \
  --prefix=/usr \
  --sbin-path=/usr/bin/nginx \
  --conf-path=/etc/nginx/nginx.conf \
  --pid-path=/run/nginx.pid \
  --with-http_ssl_module \
  --with-http_v2_module \
  --with-http_gzip_static_module \
  --with-pcre-jit

make -j$(nproc)

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 objs/nginx $OUTPUT_DIR/usr/bin/nginx
