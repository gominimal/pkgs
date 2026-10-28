#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  ARCH=x64 ;;
  aarch64) ARCH=arm64 ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

# Lay the two sha256-pinned npm tarballs out as node_modules by hand, in a
# package-PRIVATE prefix (NOT the shared usr/lib/node_modules the node runtime
# owns, #370 #751). No npm and no network: varlock has no dependencies, and its
# only optional ones are the per-platform native-helper packages, of which this
# arch's is the second Source.
NM="$OUTPUT_DIR/usr/libexec/varlock/node_modules"
install -d "$NM/varlock" "$NM/@varlock/native-helper-linux-${ARCH}"
tar -xzof "varlock-${MINIMAL_ARG_VERSION}.tgz" --strip-components=1 -C "$NM/varlock"
tar -xzof "native-helper-linux-${ARCH}-${MINIMAL_ARG_VERSION}.tgz" --strip-components=1 \
  -C "$NM/@varlock/native-helper-linux-${ARCH}"
chmod 0755 "$NM/varlock/bin/cli.js" "$NM/@varlock/native-helper-linux-${ARCH}/varlock-local-encrypt"

# Relative PATH symlinks into the private prefix. `test -e` follows the chain, so
# a moved upstream entry point fails the build rather than shipping a dangling
# link. varlock-local-encrypt stays on PATH as before; varlock also finds it as
# its @varlock/native-helper-linux-* package.
install -d "$OUTPUT_DIR/usr/bin"
ln -s ../libexec/varlock/node_modules/varlock/bin/cli.js "$OUTPUT_DIR/usr/bin/varlock"
ln -s "../libexec/varlock/node_modules/@varlock/native-helper-linux-${ARCH}/varlock-local-encrypt" \
  "$OUTPUT_DIR/usr/bin/varlock-local-encrypt"
for _tool in varlock varlock-local-encrypt; do
  test -e "$OUTPUT_DIR/usr/bin/$_tool" || { echo "varlock: $_tool missing from the tarballs" >&2; exit 1; }
done
