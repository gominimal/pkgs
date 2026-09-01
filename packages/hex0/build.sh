#!/bin/sh
# hex0 seed install — fail-shut on every property that makes the seed THE seed.
# The harness extracted the sha-pinned tarball (outer sha gated by the fetcher)
# into the build root: usr/bin/hex0. Re-verify the INNER ELF sha (the
# human-audit anchor) and the byte count, then install. No compiler, no
# network, no transformation — bytes in, bytes out, twice-checked.
set -e
[ "$(uname -m)" = x86_64 ] || { echo "hex0: FATAL amd64-only seed (the arm ladder roots at its own sealed seed)" >&2; exit 1; }
INNER=66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b
[ -f usr/bin/hex0 ] || { echo "hex0: FATAL seed tarball did not provide usr/bin/hex0" >&2; exit 1; }
have="$(sha256sum usr/bin/hex0 | cut -d' ' -f1)"
[ "$have" = "$INNER" ] || { echo "hex0: FATAL inner seed sha $have != $INNER" >&2; exit 1; }
bytes="$(wc -c < usr/bin/hex0 | tr -d ' ')"
[ "$bytes" = "229" ] || { echo "hex0: FATAL seed is $bytes bytes, expected 229" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR/usr/bin"
cp usr/bin/hex0 "$OUTPUT_DIR/usr/bin/hex0"
chmod 0755 "$OUTPUT_DIR/usr/bin/hex0"
echo "hex0: seed installed (inner sha + 229-byte gates PASSED)"
