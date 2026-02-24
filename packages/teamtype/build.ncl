let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.1" in
{
  name = "teamtype",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/teamtype/teamtype/v%{version}.tar.gz",
      sha256 = "8503411b340f00456ac6c1d586637de35a35886b7addbf2cec06816e05bc9873",
      extract = true,
      strip_prefix = "teamtype-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    teamtype = { glob = "usr/bin/teamtype" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "teamtype",
        repo = "teamtype",
      },
    } | Attrs,

  tests.smoketest = standaloneTest "/usr/bin/teamtype --version",
} | BuildSpec
