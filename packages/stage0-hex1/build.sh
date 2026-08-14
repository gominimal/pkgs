#!/bin/sh
# B1 — first attested from-source rung. Driven by attested bash + coreutils
# (NOT upstream kaem). hex0 is a pure byte transform: no timestamps, no -j, no
# host-path leak -> both outputs are trivially bit-reproducible. Byte-identity
# is asserted with coreutils' sha256sum (no diffutils/cmp), so this rung's
# attested predecessor set stays exactly { bash, coreutils }.
set -ex

cd stage0-posix-1.9.1

# Human-audit anchors: the inner-ELF sha256 of the oriansj/stage0-posix
# Release_1.9.1 hex0-seed, PER ARCHITECTURE. Both constants verified 2026-08-14
# directly against the seeds inside the sha256-pinned Source tarball above
# (33108c8c...): AMD64 = 229 bytes, AArch64 = 526 bytes. Used only as a
# defense-in-depth tripwire that Pass-3 hydrated the EXPECTED seed into
# /usr/bin/hex0; the machine trust-gate is the bootstrap_artifacts OUTER-tarball
# sha (trust-config).
#
# WHY PER-ARCH (measured in the 2026-08 world rebuild): this constant was
# AMD64-only, so on aarch64 -- where Pass-3 correctly hydrates the AArch64 seed
# (8ca9745e...) -- the tripwire fired on EVERY closure containing this rung:
# 17-18 top-level packages per arm world run, on bedrock AND baseline branches
# alike. The guard was doing its job; it just only knew one architecture.
# aarch64 self-reproduction is independently proven on Axion hardware
# (bedrock-aarch64/probes/01-hex0-selfrepro.sh).
case "$(uname -m)" in
  x86_64)  S0ARCH=AMD64;   SEED_SHA=66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b ;;
  aarch64) S0ARCH=AArch64; SEED_SHA=8ca9745e20af3f0d6037684cbc3ec3789c205d86ccecf43f77d0aeabf16050b4 ;;
  *) echo "FATAL: no audited hex0 seed for $(uname -m)" >&2; exit 1 ;;
esac

seed_have=$(sha256sum < /usr/bin/hex0 | cut -d' ' -f1)
if [ "$seed_have" != "$SEED_SHA" ]; then
  echo "FATAL: hydrated /usr/bin/hex0 sha $seed_have != audited seed $SEED_SHA" >&2
  exit 1
fi

# Phase-0 (bedrock fixed point): self-reproduce hex0 from its OWN auditable
# hex0-language source using ONLY the trusted seed, then assert byte-identity.
# Proves the seed bytes (229 on AMD64, 526 on AArch64) faithfully implement
# their own hex0-language source inside
# attested hardware. (Upstream's own audit step; we use sha256 equality.)
/usr/bin/hex0 "$S0ARCH/hex0_$S0ARCH.hex0" hex0.built
built_have=$(sha256sum < hex0.built | cut -d' ' -f1)
if [ "$built_have" != "$seed_have" ]; then
  echo "FATAL: hex0 self-reproduction mismatch: built $built_have != seed $seed_have" >&2
  exit 1
fi

# Phase-0b: build the DISTINCT hex1 assembler (adds single-character labels +
# one relational-jump size that hex0 lacks) from auditable hex0-language
# source, driven by the just-reproduced-from-source hex0 (== seed).
./hex0.built "$S0ARCH/hex1_$S0ARCH.hex0" hex1.built

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
