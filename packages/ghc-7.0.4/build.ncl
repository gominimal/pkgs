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
let amd64_spec =
  {
    name = "ghc-7.0.4",
    build_deps = [
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
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
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
    ],
    # the driver runs gcc on the C it emits and the perl mangler/splitter; the RTS links libgmp
    runtime_deps = [
      subsetOf glibc-bedrock ["sysroot_lib"],
      gmp,
      ncurses,
      perl,
      gcc-bedrock,
      binutils-bedrock,
      bash,
    ],
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
# amd64 only for now: the native code generator is x86_64 here; the arm64 lineage is being probed.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "ghc-7.0.4",
      build_deps = [],
    } | BuildSpec,
} target
