let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# mrustc 0.12.0 — ★ THE JOINT ★  (issue #17)
#
# This recipe exists to delete ONE edge of trust-by-fiat.  Today the rust chain reads:
#
#     Debian `apt-get install g++`  ->  mrustc 0.12.0  ->  rustc 1.90 -> ... -> 1.94.1 (seeds)
#     -> [CS, attested] rust 1.95.0
#
# and its ROOT is apt.  packages/rust/build.ncl says so in its own words: the seeds are "NOT
# hex0-rooted", "NOT attested", built on "a plain GCE VM: no TEE, no attestation, host compiler
# from `apt-get install g++`".  This package rebuilds mrustc's C++ host compiler edge on OUR
# seed-rooted ladder instead, inside Confidential Space, from a sha-pinned source.
#
# ── WHAT THIS PACKAGE IS, AND IS NOT ──────────────────────────────────────────────────────────
#   IS:     bin/mrustc + bin/minicargo, compiled by gcc-15.2.0-glibc (B5), the seed-rooted
#           g++ whose own chain is hex0 -> hex1 -> ... -> tcc -> gcc-4.0.4 -> ... -> gcc-10.4.0
#           -> stage0-gcc-15.2.0 (R12) -> gcc-15.2.0-glibc (B5).  Gated by making the produced
#           mrustc COMPILE a Rust program and RUN the result.
#   IS NOT: a rustc.  Building rustc 1.90.0 from mrustc needs the rustc-1.90.0-src tarball, LLVM
#           (cmake, hours, hundreds of GB) and `run_rustc`.  That is a SEPARATE downstream rung
#           (packages/mrustc-rustc-1.90.0).  Scope was split deliberately: this rung is the one
#           that can plausibly be BYTE-SEALED, and sealing the compiler is what makes the rest
#           of the chain mean anything.
#
# ── ⚠ HONESTY BOUNDARY — DO NOT OVERSTATE THIS EDGE IN ANY WRITEUP ────────────────────────────
#   1. The anchor is ATTESTED but NOT BYTE-SEALED.  gcc-15.2.0-glibc (B5) and stage0-gcc-15.2.0
#      (R12) both ship a comment-only `# UNPINNED` stage0.answers with their `sha256sum -c` gate
#      commented out (see stage0-gcc-15.2.0/build.sh:232).  An mrustc built on them inherits
#      "green", NOT "sealed".
#   2. Both anchors were signed PRE-B7-flip (bootstrap_artifacts=1) with the pre-#14 467-source
#      catalogue as their recorded closure — the "vacuous pass" regime.  Their attestation
#      ASSERTS a walked chain to hex0, it does not DEMONSTRATE one.  Re-attesting R12/B5 under
#      the post-flip RECORD_CLOSURE regime is a prerequisite before claiming this edge is
#      hex0-rooted end to end.
#   3. Nothing downstream will fail-shut if this edge regresses: packages/rust's own comment
#      records that "assess_dep_chain anchors its trust set on declaredSources shas and returns
#      None on a hit, so CHAIN_ENFORCE=1 can never flag [the seeds]".  The proof that the joint
#      landed has to come from THIS recipe's provenance, not from the chain enforcer.
#
# ── SOURCE PIN ────────────────────────────────────────────────────────────────────────────────
# Upstream's own fetch path is unpinnable: dtolnay's download.sh checksums the rustc tarballs but
# `curl`s the mrustc GitHub archive bare, with NO recorded sha anywhere.  GitHub's codeload
# tarballs are also not byte-stable over time.  So we pin the COMMIT and mirror a tarball we
# generate ourselves, deterministically, from that commit:
#
#     git clone https://github.com/thepowersgang/mrustc && cd mrustc
#     git archive --format=tar --prefix=mrustc-0.12.0/ \
#         2d14b09a7e75166bec4413f48f61e3b3cd4de8ca > mrustc-0.12.0.tar
#     sha256sum mrustc-0.12.0.tar
#       -> 1ad6521c90e47754c5e13bd9abd183f4cd953eb9faa8a25e7b104b6ffe701512
#     gcloud storage cp mrustc-0.12.0.tar gs://minimal-staging-archives/mrustc-0.12.0.tar
#
# 2d14b09a7e75166bec4413f48f61e3b3cd4de8ca IS the v0.12.0 tag ("Bump version to 0.12 with the
# 1.90 merge").  PLAIN .tar on purpose — no gzip/zstd, because compressor output varies by
# implementation and version while `git archive`'s tar stream is a pure function of the commit.
# Anyone can re-derive this sha from the public repo with one command.  The commit sha is the
# real anchor; the tarball sha is a derived convenience that build.sh re-asserts at build time.
#
# ── TAG vs MASTER (unresolved upstream fork, decided HERE) ────────────────────────────────────
# docs/rust-seed-stage0-bridge.md:53-57 recommends building the durable stage0 from mrustc MASTER
# (carrying UB fixes db7213b + aea331a) rather than v0.12.0 + our archive.rs patch-mask.  We pin
# v0.12.0 for the FIRST landed recipe because v0.12.0 is what the de-risk actually measured, and
# because "master" is a moving target that needs a commit pin anyway.  Revisit once this rung is
# green; the swap is a one-line sha change plus a re-run of the same gate.
#
# ── OFFLINE BY CONSTRUCTION ───────────────────────────────────────────────────────────────────
# `needs` is deliberately ABSENT: there is no "no network" flag, absence IS the default and the
# sandbox has none.  Stronger than that, at THIS scope the network-touching rule is UNREACHABLE:
# minicargo.mk:224's `curl` is the single network call in the whole mrustc build and it lives in
# the `$(RUSTC_SRC_TARBALL)` rule, which is only pulled in by the `RUSTCSRC`/`LIBS`/`rustc`
# targets.  We build `all` and `tools/minicargo` only, so make never evaluates it.  build.sh
# additionally installs LOUD failing stubs for curl/wget/git on PATH and asserts afterwards that
# none of them fired, so "offline" is PROVEN by the build rather than argued in a comment.
#
# ── DETERMINISM ───────────────────────────────────────────────────────────────────────────────
# mrustc's Makefile:190 compiles version.o with -D VERSION_BUILDTIME="$(shell env LC_TIME=C date
# -u ...)" plus four `git` shell-outs.  The string is a live `const char*` in .rodata
# (src/version.cpp:29), so it SURVIVES the `strip` at Makefile:180 — bin/mrustc can never be
# 2-run byte-identical unpatched.  It is also laundered a second time through the
# --add-gnu-debuglink CRC.  build.sh replaces all five `$(shell ...)` calls with make variables
# fed from the environment (verified: each needle occurs exactly once, and GNU make imports the
# multi-word buildtime intact), derives the timestamp from SOURCE_DATE_EPOCH (=0 in the sandbox),
# and then PROVES the fix by rebuilding version.o at a later wall-clock instant and asserting
# bin/mrustc is byte-identical.  NOTE: MRUSTC_GIT_ISDIRTY must be `0`, not empty —
# src/version.cpp:26 is `bool gbVersion_GitDirty = VERSION_GIT_ISDIRTY;`, an UNQUOTED macro, so
# an empty value is a hard syntax error.
#
# mrustc.answers is the byte-seal slot and it SELF-ARMS: build.sh runs `sha256sum -c` fail-shut
# the moment the file contains a real pin line, with no code change.  It ships UNPINNED because
# the shas are not knowable until two green CS builds have run.
#
# ── THE STRAND, LANDED ────────────────────────────────────────────────────────────────────────
# archive-zerolen-skip.sh is the rustc-1.90.0 fix for the mrustc-built rustc SIGABRTing on a
# zero-length mmap in ArArchiveBuilder::build_inner.  Until this commit it existed ONLY on the
# (TERMINATED, no-SA, no-external-IP) rust-ladder VM's disk and in an ephemeral /private/tmp
# scratchpad that macOS wipes on reboot.  It is not consumed at this scope — no rustc source
# here — but it is shipped as attested output data at usr/share/mrustc/patches/ so that (a) its
# bytes enter this package's resolvedDependencies, and (b) the downstream rustc rung picks it up
# from the rootfs instead of re-deriving it.  Landing it was the single highest-value action
# available in this workflow.
#
# ── ARCH ──────────────────────────────────────────────────────────────────────────────────────
# amd64-only and deliberately ungated, matching every bedrock rung and packages/rust.  arm64
# needs the aarch64 seed-rooted stage0 (#16) and the ladder there is walled at gcc.
#
# ── RUNTIME SHAPE (no runtime_deps, per bedrock convention) ───────────────────────────────────
# bin/mrustc is glibc-DYNAMIC with .interp = /usr/lib/glibc-bedrock-2.42/lib/ld-linux-x86-64.so.2
# and RUNPATH = that sysroot plus /usr/lib.  A consumer therefore needs glibc-bedrock-2.42,
# gcc-15.2.0-glibc (libstdc++.so.6, libgcc_s.so.1) and zlib in its rootfs.  Bedrock rungs do not
# declare runtime_deps (checked: R12, B5, B4, binutils-2.46-glibc all omit them) so neither do
# we — the requirement is documented here instead.
# ============================================================================================
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5: THE ANCHOR — seed-rooted g++ 15.2.0 (+ libstdc++.so.6, cc1plus, C++ headers)
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # B5-matched as/ld/ar/ranlib/objcopy/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: /usr/lib/glibc-bedrock-2.42 sysroot (headers + crt + libs + co-located UAPI)
let zlib = import "../zlib/build.ncl" in # Makefile:45 `LIBS := -lz`; src/hir/serialise_lowlevel.cpp:10 includes <zlib.h>
let bash = import "../bash/build.ncl" in # build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # Makefile determinism patch + the libc.so linker-script fixup
let grep = import "../grep/build.ncl" in # fail-shut assertions
let coreutils = import "../coreutils/build.ncl" in # sha256sum/cp/mkdir/nproc/touch/cut/od/date/timeout
let tar = import "../tar/build.ncl" in # plain .tar unpack (--no-same-owner)
let version = "0.12.0" in
let commit = "2d14b09a7e75166bec4413f48f61e3b3cd4de8ca" in
{
  name = "mrustc",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "mrustc.answers" } | Local, # byte-seal slot; SELF-ARMS once populated (see build.sh)
    { file = "archive-zerolen-skip.sh" } | Local, # the rustc-1.90.0 0-byte-object fix, landed in git at last
    { file = "gate.rs" } | Local,             # GATE 1's program; the ONLY copy -- never inline it in build.sh
    {
      # Deterministically re-derivable from the public repo — see the SOURCE PIN block above.
      url = "gs://minimal-staging-archives/mrustc-%{version}.tar",
      sha256 = "1ad6521c90e47754c5e13bd9abd183f4cd953eb9faa8a25e7b104b6ffe701512",
      extract = false, # build.sh untars with --no-same-owner (chown-hostile sandbox: the R8 wall)
    } | Source,
    gcc-bedrock,
    binutils-bedrock,
    glibc-bedrock,
    zlib,
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
  ],
  build_args = {
    include version,
    include commit,
  },
  cmd = "./build.sh",
  outputs = {
    # OutputData + allow_executable, NOT OutputBin: these link against the B4 sysroot loader at a
    # non-standard .interp path, and binutils-2.46-glibc sets the precedent of shipping bedrock
    # /usr/bin content as OutputData to keep the interpreter checker out of the loop.
    bins = { glob = "usr/bin/{mrustc,minicargo}", allow_executable = true } | OutputData,
    # the landed strand + this rung's self-describing provenance record:
    patches = { glob = "usr/share/mrustc/patches/*", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/mrustc/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "thepowersgang",
        repo = "mrustc",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
