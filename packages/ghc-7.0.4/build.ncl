let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-7.0.4: fifth rung of the source-only GHC ladder, booted by ghc-6.10.4, and the first registerised one (its x86_64
# native code generator). Installed with its own `make install` at /usr/lib/ghc-7.0.4 (bin/{ghc,ghc-pkg}, lib/ghc-7.0.4).
# pkgmgr: bootstrap_rung = "ghc"
let ghc-6-10-4 = import "../ghc-6.10.4/build.ncl" in # the boot compiler
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
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let patch = import "../patch/build.ncl" in
let version = "7.0.4" in
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
    name = "ghc-7.0.4",
    build_deps =
      [
        { file = "build.sh" } | Local,
        {
          url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.bz2",
          sha256 = "1a9b78d9d66c9c21de6c0932e36bb87406a4856f1611bf83bd44539bdc6ed0ed",
          extract = false, # build.sh untars with --no-same-owner
        } | Source,
        # the 7.0 build system wants GNU make 3.82 (4.x evaluates its rules in another order); built by build.sh
        {
          url = "gs://minimal-staging-archives/make-3.82.tar.bz2",
          sha256 = "e2c1a73f179c40c71e2fe8abf8a8a0688b8499538512984da4a76958d0402966",
          extract = false,
        } | Source,
        ghc-6-10-4,
        gmp,
        ncurses,
        base,
        bash,
        make,
        perl,
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
      prefix = { glob = "usr/lib/ghc-7.0.4/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        repology_project = "ghc",
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/7.0.4/",
        },
      } | Attrs,
  } | BuildSpec
in
spec
