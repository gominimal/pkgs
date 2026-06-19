#!/bin/sh
# B1 — first attested from-source rung. Driven by attested bash + coreutils
# (NOT upstream kaem). hex0 is a pure byte transform: no timestamps, no -j, no
# host-path leak -> both outputs are trivially bit-reproducible. Byte-identity
# is asserted with coreutils' sha256sum (no diffutils/cmp), so this rung's
# attested predecessor set stays exactly { bash, coreutils }.
set -ex

cd stage0-posix-1.9.1

# Human-audit anchor: the inner-ELF sha256 of oriansj/stage0-posix Release_1.9.1
# AMD64 hex0-seed. This is the HAND-CHECKED constant for the pinned tag (NOT a
# <RECORD-AT-PIN-TIME> value); it is used here only as a defense-in-depth
# tripwire that Pass-3 hydrated the EXPECTED seed into /usr/bin/hex0. The
# machine trust-gate is the bootstrap_artifacts OUTER-tarball sha (trust-config);
# this binds the human-audit anchor machine-side at build time as well.
SEED_SHA=66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b

seed_have=$(sha256sum < /usr/bin/hex0 | cut -d' ' -f1)
if [ "$seed_have" != "$SEED_SHA" ]; then
  echo "FATAL: hydrated /usr/bin/hex0 sha $seed_have != audited seed $SEED_SHA" >&2
  exit 1
fi

# Phase-0 (bedrock fixed point): self-reproduce hex0 from its OWN auditable
# hex0-language source using ONLY the trusted seed, then assert byte-identity.
# Proves the 229 seed bytes faithfully implement hex0_AMD64.hex0 inside
# attested hardware. (Upstream's own audit step; we use sha256 equality.)
/usr/bin/hex0 AMD64/hex0_AMD64.hex0 hex0.built
built_have=$(sha256sum < hex0.built | cut -d' ' -f1)
if [ "$built_have" != "$seed_have" ]; then
  echo "FATAL: hex0 self-reproduction mismatch: built $built_have != seed $seed_have" >&2
  exit 1
fi

# Phase-0b: build the DISTINCT hex1 assembler (adds single-character labels +
# one relational-jump size that hex0 lacks) from auditable hex0-language
# source, driven by the just-reproduced-from-source hex0 (== seed).
./hex0.built AMD64/hex1_AMD64.hex0 hex1.built

# Sanity: hex1 must be a non-empty ELF (catches a silently-truncated or
# odd-nibble assemble). coreutils only — no grep.
test -s hex1.built
magic=$(head -c 4 hex1.built | od -An -tx1 | tr -d ' \n')
if [ "$magic" != "7f454c46" ]; then
  echo "FATAL: hex1.built is not an ELF (magic=$magic)" >&2
  exit 1
fi

# Stage outputs. hex0 = self-reproduced audited monitor (byte-identical to the
# seed); hex1 = the first net-new from-source tool.
chmod 0755 hex0.built hex1.built
mkdir -p "$OUTPUT_DIR/usr/bin"
cp hex0.built "$OUTPUT_DIR/usr/bin/hex0"
cp hex1.built "$OUTPUT_DIR/usr/bin/hex1"
