let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-6.10.4: fourth rung of the source-only GHC ladder, booted by ghc-6.6.1 (6.10 needs a >= 6.4 boot). Built
# unregisterised like the rungs before it (6.10 still compiles .cmm via C). Stage 1 is compiled by 6.6.1, stage 2 by
# stage 1; stage 2's tree is installed at /usr/lib/ghc-6.10.4/ghc-6.10.4 (driven in place) plus bin/{ghc,ghc-pkg}.
# pkgmgr: bootstrap_rung = "ghc"
let ghc-6-6-1 = import "../ghc-6.6.1/build.ncl" in # the boot compiler
let gmp = import "../gmp/build.ncl" in # the RTS's Integer
let ncurses = import "../ncurses/build.ncl" in # the terminfo library binds it
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # the C compiler, hex0-rooted; build.sh wraps it against the sysroot
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let toolchain = import "../toolchain/build.ncl" in # aarch64: gcc, binutils and glibc, built from the hex0 seed
let glibc = import "../glibc/build.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in # mangler, splitter, mkdependHS
let flex = import "../flex/build.ncl" in # configure insists on lex
let bison = import "../bison/build.ncl" in # and on a parser generator
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let patch = import "../patch/build.ncl" in
let version = "6.10.4" in
let is_arm = target.arch == 'Arm64 in
# x86_64 compiles with the bedrock gcc against its glibc sysroot; aarch64 with the toolchain, itself hex0-rooted
let cc_build = if is_arm then [toolchain] else [gcc-bedrock, binutils-bedrock, glibc-bedrock] in
let cc_runtime = if is_arm then [glibc, toolchain] else [subsetOf glibc-bedrock ["sysroot_lib"], gcc-bedrock, binutils-bedrock] in
let arm_sources =
  if is_arm then
    [
      {
        url = "gs://minimal-staging-archives/libffi-3.5.2.tar.gz",
        sha256 = "f3a3082a23b37c293a4fcd1053147b371f2ff91fa7ea1b2a52e335676bac82dc",
        extract = false,
      } | Source,
    ]
  else
    []
in
let spec =
  {
    name = "ghc-6.10.4",
    build_deps =
      [
        { file = "build.sh" } | Local,
        { file = "configure-aarch64.patch" } | Local,
        {
          url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.bz2",
          sha256 = "d66a8e52572f4ff819fe5c4e34c6dd1e84a7763e25c3fadcc222453c0bd8534d",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        ghc-6-6-1,
        gmp,
        ncurses,
        base,
        bash,
        make,
        perl,
        flex,
        bison,
        sed,
        grep,
        gawk,
        coreutils,
        findutils,
        diffutils,
        tar,
        bzip2,
        patch,
      ]
      @ cc_build
      @ arm_sources,
    # the driver runs gcc on the C it emits and the perl mangler/splitter; the RTS links libgmp
    runtime_deps =
      [
        gmp,
        ncurses,
        perl,
        bash,
      ]
      @ cc_runtime,
    cmd = "./build.sh",
    outputs = {
      prefix = { glob = "usr/lib/ghc-6.10.4/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        repology_project = "ghc",
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/6.10.4/",
        },
      } | Attrs,
  } | BuildSpec
in
spec
