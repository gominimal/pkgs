let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-5.04.3: second rung of the source-only GHC ladder, booted by ghc-4.08.2. Stage 1 is compiled by 4.08.2, stage 2
# by stage 1, so no 4.08-compiled code remains in the installed compiler. Unregisterised (via C), x86_64 through the
# platform case the patches add. Installs the stage-2 build tree at /usr/lib/ghc-5.04.3/ghc-5.04.3 (the next rung
# drives it in place) plus bin/{ghc,ghc-pkg}; nothing lands on /usr/bin.
# pkgmgr: bootstrap_rung = "ghc"
let ghc-4-08-2 = import "../ghc-4.08.2/build.ncl" in # the boot compiler
let gmp = import "../gmp/build.ncl" in # the RTS's Integer
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
let version = "5.04.3" in
let is_arm = target.arch == 'Arm64 in
# x86_64 compiles with the bedrock gcc against its glibc sysroot; aarch64 with the toolchain, itself hex0-rooted
let cc_build = if is_arm then [toolchain] else [gcc-bedrock, binutils-bedrock, glibc-bedrock] in
let cc_runtime = if is_arm then [glibc, toolchain] else [subsetOf glibc-bedrock ["sysroot_lib"], gcc-bedrock, binutils-bedrock] in
let spec =
  {
    name = "ghc-5.04.3",
    build_deps =
      [
        { file = "build.sh" } | Local,
        { file = "driver-aarch64.patch" } | Local,
        { file = "configure-aarch64.patch" } | Local,
        {
          url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.bz2",
          sha256 = "c662589383d49fd4c128f13789b29a7f7db55e9d146032519bfb1c796d8f7153",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        # in series order; the boot408-* patches take their >= 500 branches in stage 2
        { file = "configure-x86_64.patch" } | Local,
        { file = "mblock-64bit.patch" } | Local,
        { file = "cast-lvalue.patch" } | Local,
        { file = "rts-carry.patch" } | Local,
        { file = "driver-x86_64.patch" } | Local,
        { file = "gcc15-c.patch" } | Local,
        { file = "boot408-hschooks.patch" } | Local,
        { file = "boot408-happy64.patch" } | Local,
        { file = "gcc15-rts-net.patch" } | Local,
        { file = "glibc-modern.patch" } | Local,
        { file = "boot408-floatlit.patch" } | Local,
        { file = "uniqfm-64bit.patch" } | Local,
        ghc-4-08-2,
        gmp,
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
      @ cc_build,
    # the driver runs gcc on the C it emits and the perl mangler/splitter; the RTS links libgmp
    runtime_deps =
      [
        gmp,
        perl,
        bash,
      ]
      @ cc_runtime,
    cmd = "./build.sh",
    outputs = {
      prefix = { glob = "usr/lib/ghc-5.04.3/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        repology_project = "ghc",
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/5.04.3/",
        },
      } | Attrs,
  } | BuildSpec
in
spec
