#!/bin/sh
# Rebuild hex0 from source with the seed, assert byte-identity, then assemble hex1.
# Uses only bash and coreutils (sha256sum for the identity check, no cmp/grep).
# hex0 is a pure byte transform, so both outputs are bit-reproducible.
set -ex

cd stage0-posix-1.9.1

# sha256 of the oriansj/stage0-posix Release_1.9.1 AMD64 hex0 seed; checks that
# /usr/bin/hex0 in the rootfs is the expected seed before it is used.
SEED_SHA=66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b

seed_have=$(sha256sum < /usr/bin/hex0 | cut -d' ' -f1)
if [ "$seed_have" != "$SEED_SHA" ]; then
  echo "FATAL: hydrated /usr/bin/hex0 sha $seed_have != audited seed $SEED_SHA" >&2
  exit 1
fi

# Assemble hex0 from its own hex0-language source with the seed; the result must
# equal the seed byte for byte (upstream's audit step, done with sha256 equality).
/usr/bin/hex0 AMD64/hex0_AMD64.hex0 hex0.built
built_have=$(sha256sum < hex0.built | cut -d' ' -f1)
if [ "$built_have" != "$seed_have" ]; then
  echo "FATAL: hex0 self-reproduction mismatch: built $built_have != seed $seed_have" >&2
  exit 1
fi

# Assemble hex1 (adds single-character labels and one relative-jump size) with the
# rebuilt hex0.
./hex0.built AMD64/hex1_AMD64.hex0 hex1.built

# hex1 must be a non-empty ELF; catches a truncated or odd-nibble assemble.
test -s hex1.built
magic=$(head -c 4 hex1.built | od -An -tx1 | tr -d ' \n')
if [ "$magic" != "7f454c46" ]; then
  echo "FATAL: hex1.built is not an ELF (magic=$magic)" >&2
  exit 1
fi

# Install both tools.
chmod 0755 hex0.built hex1.built
mkdir -p "$OUTPUT_DIR/usr/bin"
cp hex0.built "$OUTPUT_DIR/usr/bin/hex0"
cp hex1.built "$OUTPUT_DIR/usr/bin/hex1"
