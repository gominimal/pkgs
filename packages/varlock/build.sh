#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  ARCH=x64 ;;
  aarch64) ARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tar -xzof "varlock-linux-${ARCH}-${MINIMAL_ARG_VERSION}.tar.gz"

install -D -m 0755 varlock "$OUTPUT_DIR/usr/bin/varlock"
