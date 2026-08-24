# BuDDy — a Binary Decision Diagram (BDD) library (C++). A Maude build
# prerequisite; see pkgmgr-rs#528.
let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } =
  import "minimal.ncl"
in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "2.4" in
{
  name = "buddy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/buddy-%{version}.tar.gz",
      sha256 = "8cfe7d86537a0d7edb44e2cbf0624716b55adcafb10140751c40ad9430f3d0b8",
      extract = true,
      strip_prefix = "buddy-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # BuDDy ships its own permissive academic license (Jørn Lind-Nielsen, in
      # src/*.h): grants use / derivative works / distribute for any purpose with
      # attribution + no-warranty, and lets modifications be relicensed. No exact
      # SPDX match — GitHub licensee returns NOASSERTION; the closest standard is
      # SWL (identical disclaimer + modification clause) but the grant wording
      # differs — so a LicenseRef per minimal convention (cf. LicenseRef-Public-Domain).
      license_spdx = "LicenseRef-BuDDy",
      source_provenance = {
        category = 'GithubRepo,
        owner = "utwente-fmt",
        repo = "buddy",
      },
    } | Attrs,
} | BuildSpec
