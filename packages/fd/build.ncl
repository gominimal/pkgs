let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "10.5.1" in
{
  name = "fd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sharkdp/fd/v%{version}.tar.gz",
      sha256 = "3ea70c258d3390a601b436b6f4c545e3a944ff3de44c8ee5542c05588e337032",
      extract = true,
      strip_prefix = "fd-%{version}",
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
    fd = { glob = "usr/bin/fd" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sharkdp",
        repo = "fd",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/fd --version",
  },
} | BuildSpec
