#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  PLATFORM="x86_64" ;;
  aarch64) PLATFORM="aarch64" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tar -xof shellcheck-v${MINIMAL_ARG_VERSION}.linux.${PLATFORM}.tar.xz

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 shellcheck-v${MINIMAL_ARG_VERSION}/shellcheck $OUTPUT_DIR/usr/bin/shellcheck
