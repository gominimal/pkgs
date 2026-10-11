let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in # applies the three wrap patches
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # the C compiler, hex0-rooted; build.sh wraps it against the sysroot
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
let toolchain = import "../toolchain/build.ncl" in # aarch64: gcc, binutils and glibc, built from the hex0 seed
let glibc = import "../glibc/build.ncl" in
# microhs-0.16: MicroHs, a Haskell compiler whose own compiled form ships as portable C (generated/mhs.c), so gcc alone
# yields a Haskell compiler. Root of the source-only GHC ladder (microhs -> ghc-4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 ->
# 7.0.4 -> 7.6.3 -> ...). Installs at /usr/lib/microhs-0.16; nothing lands on /usr/bin.
# Source mirrored to gs://minimal-staging-archives/ from hackage. No `needs`: nothing here touches the network.
# pkgmgr: bootstrap_rung = "ghc"
let version = "0.16.0.0" in
let is_arm = target.arch == 'Arm64 in
# x86_64 compiles with the bedrock gcc against its glibc sysroot; aarch64 with the toolchain, itself hex0-rooted
let cc_build = if is_arm then [toolchain] else [gcc-bedrock, binutils-bedrock, glibc-bedrock] in
let cc_runtime = if is_arm then [glibc, toolchain] else [subsetOf glibc-bedrock ["sysroot_lib"], gcc-bedrock, binutils-bedrock] in
let spec =
  {
    name = "microhs-0.16",
    build_deps =
      [
        { file = "build.sh" } | Local,
        { file = "eval-wrap.patch" } | Local,
        { file = "lib-wrap.patch" } | Local,
        { file = "integer-type.patch" } | Local,
        {
          url = "gs://minimal-staging-archives/MicroHs-%{version}.tar.gz",
          sha256 = "d8cfa846765ee091098abb2abb83aa36ee0c1fbb57ac8a53c43c169761493155",
          extract = true,
          strip_prefix = "MicroHs-%{version}",
        } | Source,
        base,
        make,
        patch,
      ]
      @ cc_build,
    # the interpreter binaries load libm and libc; the Haskell library is data mhs reads at compile time
    runtime_deps =
      []
      @ cc_runtime,
    cmd = "./build.sh",
    # the in-place layout mhs needs: bin/, the Haskell library lib/, the runtime C src/runtime/ that `mhs -o` links
    # against, and mhs.conf
    outputs = {
      prefix = { glob = "usr/lib/microhs-0.16/**", allow_executable = true } | OutputData,
    },
    attrs =
      {
        upstream_version = version,
        license_spdx = "Apache-2.0",
        repology_project = "microhs",
        source_provenance = {
          category = 'GithubRepo,
          owner = "augustss",
          repo = "MicroHs",
        },
      } | Attrs,
  } | BuildSpec
in
spec
