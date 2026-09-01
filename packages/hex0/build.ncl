let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
# hex0 — THE seed. The 229-byte hand-auditable hex0 monitor
# (oriansj/stage0-posix Release_1.9.1, AMD64), the sole bedrock root of
# trust for the attested-from-source toolchain ladder.
#
# Delivered as a sha-pinned Source: the deterministic zstd tarball (GNU tar
# 1.34 + zstd 1.5.4) wraps the seed at usr/bin/hex0 mode 0755. The OUTER
# tarball sha below gates the fetched bytes; the INNER ELF sha
# (66c95985e668f20f2465c2b876f83fef066fd7c8c2dd3adb51a969f2d7120c8b,
# 229 bytes) is the human-audit anchor, re-checked fail-shut in build.sh.
#
# PROVENANCE (verified 2026-06-20, native-amd64 acceptance gate PASSED:
# executes unmodified rc=0, self-reproduces byte-identical, hex1 assembles):
# raw ELF64 static (ET_EXEC, non-PIE, no section headers, no .interp), from
# stage0-posix supermodule 45d90f5955b6907dc6cdea9ebafce558359edcd3,
# bootstrap-seeds submodule cedec6b8066d1db229b6c77d42d120a23c6980ed, AMD64
# submodule 82efa0d6be1c9bb993a7a62af1cccd8d2cda91f6. Provably
# byte-identical to its own annotated source AMD64/hex0_AMD64.hex0 (strip
# comments, pack hex pairs -> same sha).
#
# In the CS builder the same bytes also arrive via the trust-config
# `bootstrap_artifacts` entry (Pass-3 hydration preempts this build) — the
# two paths pin the SAME outer sha, so either way the slot holds the seed.
# amd64-only: the arm ladder roots at its own sealed seed (bedrock-aarch64).
{
  name = "hex0",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/seeds/stage0-posix/Release_1.9.1/hex0-seed-amd64.tar.zst",
      sha256 = "be2533eccbd0547e50a9bce4fd6571727365b0896b65fecbb232a623b1f36959",
      extract = true,
    } | Source,
    (import "../bash-bootstrap/build.ncl"), # /bin/sh for build.sh
    (import "../coreutils/build.ncl"), # sha256sum/wc/cp/mkdir/chmod — the fail-shut inner-sha tripwire
  ],
  cmd = "./build.sh",
  outputs = {
    # allow_missing_interpreter: the seed is a static ELF with no .interp
    # (same flag gzip uses for static bins).
    hex0 = { glob = "usr/bin/hex0", allow_missing_interpreter = true } | OutputBin,
  },
} | BuildSpec
