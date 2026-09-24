#!/bin/sh
# hex0 seed install. The harness extracted the arch-matched tarball into the build
# root as usr/bin/hex0; re-check the inner ELF sha and byte count, then copy to
# $OUTPUT_DIR. No compiler, no transformation.
set -e
case "$(uname -m)" in
  x86_64)
    INNER=66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b
    BYTES=229
    ;;
  aarch64)
    INNER=8ca9745e20af3f0d6037684cbc3ec3789c205d86ccecf43f77d0aeabf16050b4
    BYTES=526
    ;;
  *) echo "hex0: FATAL no seed for $(uname -m) (amd64 + aarch64 only)" >&2; exit 1 ;;
esac
[ -f usr/bin/hex0 ] || { echo "hex0: FATAL seed tarball did not provide usr/bin/hex0" >&2; exit 1; }
have="$(sha256sum usr/bin/hex0 | cut -d' ' -f1)"
[ "$have" = "$INNER" ] || { echo "hex0: FATAL inner seed sha $have != $INNER" >&2; exit 1; }
bytes="$(wc -c < usr/bin/hex0 | tr -d ' ')"
[ "$bytes" = "$BYTES" ] || { echo "hex0: FATAL seed is $bytes bytes, expected $BYTES" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR/usr/bin"
cp usr/bin/hex0 "$OUTPUT_DIR/usr/bin/hex0"
chmod 0755 "$OUTPUT_DIR/usr/bin/hex0"
echo "hex0: $(uname -m) seed installed (inner sha + $BYTES-byte gates PASSED)"
