let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# ghc-6.6.1: third rung of the source-only GHC ladder, booted by ghc-5.04.3; the first release with an x86_64 port.
# Built unregisterised (via C): its native code generator cannot do the RTS's Cmm loops and registerised via-C needs
# the evil mangler, which a modern perl and gcc no longer survive. Stage 1 is compiled by 5.04.3, stage 2 by stage 1;
# stage 2's tree is installed at /usr/lib/ghc-6.6.1/ghc-6.6.1 (driven in place) plus bin/{ghc,ghc-pkg}.
# pkgmgr: bootstrap_rung = "ghc"
let ghc-5-04-3 = import "../ghc-5.04.3/build.ncl" in # the boot compiler
let gmp = import "../gmp/build.ncl" in # the RTS's Integer
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # the C compiler, hex0-rooted; build.sh wraps it against the sysroot
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
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
let version = "6.6.1" in
let amd64_spec =
  {
    name = "ghc-6.6.1",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        url = "gs://minimal-staging-archives/ghc-%{version}-src.tar.bz2",
        sha256 = "489126ceeb2dbb6a85ef8d87d6792e61e1bc0d5882e4b33a7725410d796132c6",
        extract = false, # build.sh untars with --no-same-owner
      } | Source,
      { file = "configure-perl.patch" } | Local, # configure accepts only perl 5.6/5.8 by version string
      ghc-5-04-3,
      gmp,
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
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
    ],
    # the driver runs gcc on the C it emits and the perl mangler/splitter; the RTS links libgmp
    runtime_deps = [
      subsetOf glibc-bedrock ["sysroot_lib"],
      gmp,
      perl,
      gcc-bedrock,
      binutils-bedrock,
      bash,
    ],
    cmd = "./build.sh",
    outputs = {
      prefix = { glob = "usr/lib/ghc-6.6.1/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "BSD-3-Clause",
        repology_project = "ghc",
        source_provenance = {
          category = 'Website,
          homepage = "https://www.haskell.org/ghc/",
          downloads_page = "https://downloads.haskell.org/~ghc/6.6.1/",
        },
      } | Attrs,
  } | BuildSpec
in
# amd64 only for now: the unregisterised build is proven on x86_64; the arm64 lineage is being probed.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "ghc-6.6.1",
      build_deps = [],
    } | BuildSpec,
} target
