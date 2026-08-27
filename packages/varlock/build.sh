#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  ARCH=x64 ;;
  aarch64) ARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# 1.x dropped the version from the asset filename (varlock-linux-${ARCH}.tar.gz).
tar -xzof "varlock-linux-${ARCH}.tar.gz"

install -D -m 0755 varlock "$OUTPUT_DIR/usr/bin/varlock"
# 1.x ships a bundled native helper alongside the main binary; varlock invokes
# it by name for local-encrypt, so install it next to the CLI or that breaks.
install -D -m 0755 varlock-local-encrypt "$OUTPUT_DIR/usr/bin/varlock-local-encrypt"
