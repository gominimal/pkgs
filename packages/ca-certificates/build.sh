#!/bin/sh
set -ex

tar --no-same-owner -xzf ssl-certs-complete-v2.tar.gz

mkdir -p "$OUTPUT_DIR/etc/ssl"
cp -r certs "$OUTPUT_DIR/etc/ssl/"

cd "$OUTPUT_DIR/etc/ssl/certs"
for cert in *.crt; do
    hash=$(openssl x509 -hash -noout -in "$cert" 2>/dev/null)
    ln -sf "$cert" "${hash}.0"
done
