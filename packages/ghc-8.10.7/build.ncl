let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-8.10.7: one rung of the GHC ladder (7.6.3 -> 7.8.4 -> 7.10.3 -> 8.2.2 -> 8.6.5 -> 8.10.7 -> 9.2.8 -> 9.6.7 -> ghc).
# Builds GHC 8.10.7 from the pinned source tarball with ../ghc-8.6.5 as the boot compiler and installs
# the whole compiler at /usr/lib/ghc-8.10.7 for the next rung; nothing lands on /usr/bin.
# Source: https://downloads.haskell.org/~ghc/8.10.7/ghc-8.10.7-src.tar.xz mirrored to gs://minimal-staging-archives/.
# No `needs`: nothing here touches the network. amd64 only (see the match at the bottom).
let ghc-boot = import "../ghc-8.6.5/build.ncl" in # the previous rung
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # asserted by build.sh
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let gmp = import "../gmp/build.ncl" in # integer-gmp
let ncurses = import "../ncurses/build.ncl" in # terminfo
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in # the build system's generators
let python = import "../python/build.ncl" in # configure probes for it
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
let version = "8.10.7" in
let amd64_spec =
  {
    name = "ghc-8.10.7",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.xz",
        sha256 = "e3eef6229ce9908dfe1ea41436befb0455fefb1932559e860ad4c606b0d03c9d",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      ghc-boot,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
      gmp,
      ncurses,
      bash,
      make,
      perl,
      python,
      sed,
      grep,
      gawk,
      coreutils,
      findutils,
      diffutils,
      tar,
      xz,
    ],
    cmd = "./build.sh",
    outputs = {
      # The next rung consumes the tree by absolute path: compiler, ghc-pkg, package db, libraries
      # and the C compiler wrapper `settings` names.
      ghc = { glob = "usr/lib/ghc-8.10.7/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/ghc-8.10.7/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        build_cost_multiple = 4,
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/8.10.7/",
        },
      } | Attrs,
  } | BuildSpec
in
# amd64 only: this rung belongs to the amd64 bootstrap ladder. On arm64 the ghc recipe keeps its
# prebuilt boot, so this spec collapses to an empty collection there.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "ghc-8.10.7",
      build_deps = [],
    } | BuildSpec,
} target
