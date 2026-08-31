let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# go-1.4 — THE GO JOINT (issue #19): the last C-hosted Go toolchain, built by the seed-rooted
# gcc-15.2.0 (B5).  This is the rung that retires the trust-by-fiat go.dev bindist.
#
#   IS:     /usr/lib/go-1.4 — a WORKING Go 1.4 whose ONLY compiler input was C, compiled by the
#           B5 gcc whose own chain is hex0 -> hex1 -> ... -> tcc -> gcc-4.0.4 -> ... ->
#           gcc-15.2.0 -> gcc-15.2.0-glibc.  Gated by making the produced Go compile AND RUN a
#           program (never a --version-only gate; see build.sh's FUNCTIONAL GATE).
#   IS NOT: a modern Go.  Go 1.4 is the BOOTSTRAP.  The ladder above it is:
#             go-1.4 -> go-1.17.13 -> go-1.20.14 -> go-1.22.6 -> go-1.24.x -> go (shipped pin)
#           each rung importing its predecessor and setting GOROOT_BOOTSTRAP to that prefix —
#           structurally identical to rustc-1.91.1 importing ../mrustc-rustc-1.90.0.
#
# WHY 1.4: it is the LAST release whose whole toolchain is C (src/cmd/dist = 10 .c, 0 .go —
# build.sh re-verifies this on the actual bytes, fail-shut).  1.5+ is self-hosted and needs a
# pre-existing Go binary — the chicken-and-egg this rung breaks with gcc alone.
#
# ── DE-RISKED 2026-07-26 ─────────────────────────────────────────────────────────────────────
# gcc-15 defaults to C23, where `bool` is a KEYWORD, so cmd/dist/a.h:5's `typedef int bool;` is a
# hard error (make.bash also hardcodes -Werror).  With CC carrying `-std=gnu17 -Wno-error` the
# build is rc=0 / zero errors and the produced Go compiles+runs a real program.  Same C23 trap
# family as the aarch64 ladder's musl basename() and libiberty K&R malloc() walls.
#
# ── SOURCE PIN ───────────────────────────────────────────────────────────────────────────────
# Mirrored to staging-archives (never depend on an upstream URL in the fetcher's hot path):
#   https://go.dev/dl/go1.4-bootstrap-20171003.tar.gz   (NOTE: the storage.googleapis.com/golang
#   path now 403s) -> gs://minimal-staging-archives/go1.4-bootstrap-20171003.tar.gz
#   sha256 f4ff5b5eb3a3cae1c993723f3eab519c5bae18866b5e5f96fe1102f0cb5c3e52  (11009739 B)
#
# ── SCOPE ────────────────────────────────────────────────────────────────────────────────────
# amd64 ONLY.  arm64 support landed in Go 1.5, so the C root cannot directly produce an arm64
# toolchain; arm64 needs an amd64 host cross-bootstrapping via bootstrap.bash — a separate track
# (mirrors the arm64 deferral in #16).
#
# `needs` is deliberately ABSENT: absence IS the no-network default.  Unlike the shipped `go`
# recipe (which fetches a bindist), nothing here touches the network — Go's stdlib is
# self-contained, so this rung is strictly MORE hermetic than the recipe it replaces.
# ============================================================================================
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5: THE ANCHOR — seed-rooted gcc 15.2.0
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # B5-matched as/ld/ar/ranlib/objcopy/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: /usr/lib/glibc-bedrock-2.42 sysroot
let bash = import "../bash/build.ncl" in # make.bash + build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # the B4 libc.so linker-script fixup
let grep = import "../grep/build.ncl" in # fail-shut assertions
let coreutils = import "../coreutils/build.ncl" in # sha256sum/cp/mkdir/uname/timeout/find/wc
let tar = import "../tar/build.ncl" in
let version = "1.4" in
{
  name = "go-1.4",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/go1.4-bootstrap-20171003.tar.gz",
      sha256 = "f4ff5b5eb3a3cae1c993723f3eab519c5bae18866b5e5f96fe1102f0cb5c3e52",
      extract = false, # build.sh untars with --no-same-owner (chown-hostile sandbox: the R8 wall)
    } | Source,
    gcc-bedrock,
    binutils-bedrock,
    glibc-bedrock,
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # OutputData + allow_executable, NOT OutputBin: these link against the B4 sysroot loader at a
    # non-standard .interp path (the binutils-2.46-glibc precedent), which keeps the interpreter
    # checker out of the loop.  The WHOLE GOROOT ships — bin + pkg + src + lib — because a Go
    # toolchain compiles the stdlib sources of its own GOROOT, and the next rung consumes this
    # tree as GOROOT_BOOTSTRAP.
    goroot = { glob = "usr/lib/go-1.4/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/go-1.4/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "golang",
        repo = "go",
      },
    } | Attrs,
} | BuildSpec
