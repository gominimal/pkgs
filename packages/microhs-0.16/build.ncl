let { subsetOf, Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # the C compiler, hex0-rooted; build.sh wraps it against the sysroot
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # sysroot
# microhs-0.16: MicroHs, a Haskell compiler whose own compiled form ships as portable C (generated/mhs.c), so gcc alone
# yields a Haskell compiler. Root of the source-only GHC ladder (microhs -> ghc-4.08.2 -> 5.04.3 -> 6.6.1 -> 6.10.4 ->
# 7.0.4 -> 7.6.3 -> ...). Installs at /usr/lib/microhs-0.16; nothing lands on /usr/bin.
# Source mirrored to gs://minimal-staging-archives/ from hackage. No `needs`: nothing here touches the network.
# pkgmgr: bootstrap_rung = "ghc"
let version = "0.16.0.0" in
let amd64_spec =
  {
    name = "microhs-0.16",
    build_deps = [
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
      gcc-bedrock,
      binutils-bedrock,
      glibc-bedrock,
    ],
    # the interpreter binaries load libm and libc; the Haskell library is data mhs reads at compile time
    runtime_deps = [
      subsetOf glibc-bedrock ["sysroot_lib"],
    ],
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
# amd64 only for now: the bedrock toolchain it builds with is amd64; the arm64 lineage is being probed.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "microhs-0.16",
      build_deps = [],
    } | BuildSpec,
} target
