let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-7.8.4: one rung of the GHC ladder (7.6.3 -> 7.8.4 -> 7.10.3 -> 8.2.2 -> 8.6.5 -> 8.10.7 -> 9.2.8 -> 9.6.7 -> ghc).
# Builds GHC 7.8.4 from the pinned source tarball with ../ghc-7.6.3 as the boot compiler and installs
# the whole compiler at /usr/lib/ghc-7.8.4 for the next rung; nothing lands on /usr/bin.
# Source: https://downloads.haskell.org/~ghc/7.8.4/ghc-7.8.4-src.tar.xz mirrored to gs://minimal-staging-archives/.
# No `needs`: nothing here touches the network. amd64 only (see the match at the bottom).
let ghc-boot = import "../ghc-7.6.3/build.ncl" in # the previous rung
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # asserted by build.sh
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let toolchain = import "../toolchain/build.ncl" in # aarch64: gcc, binutils and glibc, built from the hex0 seed
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
let gzip = import "../gzip/build.ncl" in # the build system untars the bundled libffi
let patch = import "../patch/build.ncl" in # and patches it
# pkgmgr: bootstrap_rung = "ghc"
let version = "7.8.4" in
let is_arm = target.arch == 'Arm64 in
# x86_64 compiles with the bedrock gcc against its glibc sysroot; aarch64 with the toolchain, itself hex0-rooted
let cc_build = if is_arm then [toolchain] else [gcc-bedrock, binutils-bedrock, glibc-bedrock] in
let arm_extra =
  if is_arm then
    [
      {
        url = "gs://minimal-staging-archives/libffi-3.5.2.tar.gz",
        sha256 = "f3a3082a23b37c293a4fcd1053147b371f2ff91fa7ea1b2a52e335676bac82dc",
        extract = false,
      } | Source,
      {
        url = "gs://minimal-staging-archives/build-aux/gnu-config-config.guess",
        sha256 = "e3d148130e9151735f8b9a8e69a70d06890ece51468a9762eb7ac0feddddcc2f",
        extract = false,
      } | Source,
      {
        url = "gs://minimal-staging-archives/build-aux/gnu-config-config.sub",
        sha256 = "11c54f55c3ac99e5d2c3dc2bb0bcccbf69f8223cc68f6b2438daa806cf0d16d8",
        extract = false,
      } | Source,
    ]
  else
    []
in
let spec =
  {
    name = "ghc-7.8.4",
    build_deps =
      [
        { file = "build.sh" } | Local,
        {
          url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.xz",
          sha256 = "c319cd94adb284177ed0e6d21546ed0b900ad84b86b87c06a99eac35152982c4",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        ghc-boot,
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
        gzip,
        patch,
      ]
      @ cc_build
      @ arm_extra,
    cmd = "./build.sh",
    outputs = {
      # The next rung consumes the tree by absolute path: compiler, ghc-pkg, package db, libraries
      # and the C compiler wrapper `settings` names.
      ghc = { glob = "usr/lib/ghc-7.8.4/**", allow_executable = true } | OutputData,
      buildinfo = { glob = "usr/share/ghc-7.8.4/BUILDINFO" } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        build_cost_multiple = 4,
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/7.8.4/",
        },
      } | Attrs,
  } | BuildSpec
in
spec
