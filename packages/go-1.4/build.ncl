let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# go-1.4: root of the Go bootstrap ladder (go-1.4 -> 1.17.13 -> 1.20.14 -> 1.22.6 -> 1.24.9 -> go).
# Go 1.4 is the last release whose whole toolchain is C (src/cmd/dist has no .go files), so gcc
# alone builds it; every later rung needs a working Go as GOROOT_BOOTSTRAP.
# Built with gcc-15.2.0-glibc against the glibc-bedrock-2.42 sysroot (CC gets -std=gnu17: gcc-15's
# C23 default rejects cmd/dist's `typedef int bool;`); ships the whole GOROOT at /usr/lib/go-1.4.
# Source: https://go.dev/dl/go1.4-bootstrap-20171003.tar.gz mirrored to gs://minimal-staging-archives/.
# No `needs`: nothing touches the network.  amd64 only: arm64 support arrived in Go 1.5.
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # gcc 15.2.0, asserted by build.sh
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # as/ld/ar/ranlib/objcopy/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # /usr/lib/glibc-bedrock-2.42 sysroot
let bash = import "../bash/build.ncl" in # make.bash + build.sh interpreter
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in # libc.so linker-script fixup
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in # sha256sum/cp/mkdir/uname/timeout
let tar = import "../tar/build.ncl" in
let version = "1.4" in
let amd64_spec =
  {
    name = "go-1.4",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/go1.4-bootstrap-20171003.tar.gz",
        sha256 = "f4ff5b5eb3a3cae1c993723f3eab519c5bae18866b5e5f96fe1102f0cb5c3e52",
        extract = false, # build.sh untars with --no-same-owner (the sandbox cannot chown)
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
      # OutputData + allow_executable rather than OutputBin: the binaries use the sysroot loader
      # at a non-standard .interp path.  The whole GOROOT ships (bin + pkg + src + lib) because
      # the next rung uses this tree as GOROOT_BOOTSTRAP and Go compiles its own stdlib sources.
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
in
# amd64 only: this rung belongs to the amd64 bootstrap ladder.  On arm64 the shipped go recipe
# consumes a sha-pinned prebuilt instead, so this spec collapses to an empty collection there.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "go-1.4",
      build_deps = [],
    } | BuildSpec,
} target
