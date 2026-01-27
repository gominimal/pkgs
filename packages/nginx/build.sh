#!/bin/sh
set -ex

export CC=gcc
export CFLAGS="-march=x86-64-v3 -O3 -pipe"

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
