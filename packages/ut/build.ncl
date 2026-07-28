let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.7.0" in
{
  name = "ut",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ksdme/ut/v%{version}.tar.gz",
      sha256 = "dcea0b15bb1a64693ec26cde1b0cb8d04b74ffb0b1f77a342f4d942f765f592d",
      extract = true,
      strip_prefix = "ut-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    ut = { glob = "usr/bin/ut" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ksdme",
        repo = "ut",
      },
    } | Attrs,
} | BuildSpec
