let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# go-1.17.13 — the FIRST self-hosted rung of the Go ladder (issue #19).
#
#   IS:     /usr/lib/go-1.17.13 — a Go 1.17.13 toolchain built BY go-1.4, the C-rooted joint.
#   IS NOT: the shipped Go.  1.17.13 is the minimum bootstrap for Go 1.20, so the ladder is
#             go-1.4 -> [THIS] -> go-1.20.14 -> go-1.22.6 -> go-1.24.x -> go
#           each rung importing its predecessor and pointing GOROOT_BOOTSTRAP at that prefix —
#           structurally identical to rustc-1.91.1 importing ../mrustc-rustc-1.90.0.
#
# WHY THIS RUNG PROVES THE LADDER: go1.17's own src/cmd/dist is 15 .go FILES (self-hosted), so it
# CANNOT be built without a working Go.  go-1.4 (10 .c files, 0 .go) is what supplies it — which
# is precisely the chicken-and-egg the C-rooted rung breaks.  build.sh asserts both halves of that
# claim on the actual bytes, fail-shut.
#
# Chain: hex0 -> hex1 -> ... -> tcc -> gcc-4.0.4 -> ... -> gcc-15.2.0 -> gcc-15.2.0-glibc ->
#        go-1.4 (C only) -> THIS.
#
# ── SOURCE PIN ───────────────────────────────────────────────────────────────────────────────
#   https://go.dev/dl/go1.17.13.src.tar.gz -> gs://minimal-staging-archives/go1.17.13.src.tar.gz
#   sha256 a1a48b23afb206f95e7bbaa9b898d965f90826f6f1d1fc0c1d784ada0cd300fd  (22206518 B)
#
# amd64 only (see go-1.4's banner: arm64 needs a cross-bootstrap track).
# `needs` is deliberately ABSENT: nothing here touches the network.  Go's stdlib is
# self-contained and GOFLAGS=-trimpath keeps paths out of the binaries.
# ============================================================================================
let go-1-4 = import "../go-1.4/build.ncl" in # THE ANCHOR: the C-rooted Go (GOROOT_BOOTSTRAP)
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5 seed-rooted gcc (asserted; cgo-less)
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4 sysroot
let bash = import "../bash/build.ncl" in # make.bash + build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in # sha256sum/cp/mkdir/uname/timeout/rm
let tar = import "../tar/build.ncl" in
let version = "1.17.13" in
{
  name = "go-1.17.13",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/go%{version}.src.tar.gz",
      sha256 = "a1a48b23afb206f95e7bbaa9b898d965f90826f6f1d1fc0c1d784ada0cd300fd",
      extract = false, # build.sh untars with --no-same-owner (chown-hostile sandbox)
    } | Source,
    go-1-4,
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
    # ONE recursive OutputData glob over the whole versioned prefix (the rustc-1.94.1 precedent):
    # consumed AS DATA by the next rung via absolute path, so it must NOT land on /usr/bin (that
    # is packages/go's slot).  The WHOLE GOROOT ships — bin + pkg + src + lib — because a Go
    # toolchain compiles the stdlib sources of its own GOROOT and the next rung needs it complete.
    goroot = { glob = "usr/lib/go-1.17.13/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/go-1.17.13/BUILDINFO" } | OutputData,
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
