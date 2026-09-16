let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# go-1.17.13: one rung of the Go bootstrap ladder (go-1.4 -> 1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9 -> go).
# Builds Go 1.17.13 from the pinned source tarball with ../go-1.4 as GOROOT_BOOTSTRAP and ships the
# whole GOROOT at /usr/lib/go-1.17.13 for the next rung.
# Source: https://go.dev/dl/go1.17.13.src.tar.gz mirrored to gs://minimal-staging-archives/.
# No `needs`: nothing here touches the network.  amd64 only (see the match at the bottom).
let go-1-4 = import "../go-1.4/build.ncl" in # the previous rung (GOROOT_BOOTSTRAP)
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # asserted by build.sh; no cgo
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let bash = import "../bash/build.ncl" in # make.bash + build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in # sha256sum/cp/mkdir/uname/timeout/rm
let tar = import "../tar/build.ncl" in
let version = "1.17.13" in
let amd64_spec =
  {
    name = "go-1.17.13",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/go%{version}.src.tar.gz",
        sha256 = "a1a48b23afb206f95e7bbaa9b898d965f90826f6f1d1fc0c1d784ada0cd300fd",
        extract = false, # build.sh untars with --no-same-owner (the sandbox cannot chown)
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
      # One recursive OutputData glob over the versioned prefix: the next rung consumes this tree
      # as data by absolute path, so nothing lands on /usr/bin (that is packages/go's slot).
      # The whole GOROOT ships (bin + pkg + src + lib) because Go compiles its own stdlib sources.
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
in
# amd64 only: this rung belongs to the amd64 bootstrap ladder.  On arm64 the shipped go recipe
# consumes a sha-pinned prebuilt instead, so this spec collapses to an empty collection there.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "go-1.17.13",
      build_deps = [],
    } | BuildSpec,
} target
