let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.28.1" in
{
  name = "cloud-sql-proxy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/GoogleCloudPlatform/cloud-sql-proxy/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "c3bfb10030df2b4cad909e26aa4a1f003dd1d0a829e7001de57d3e3074822cb6",
      extract = true,
      strip_prefix = "cloud-sql-proxy-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cloud-sql-proxy = { glob = "usr/bin/cloud-sql-proxy" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "GoogleCloudPlatform",
        repo = "cloud-sql-proxy",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/cloud-sql-proxy --version",
  },
} | BuildSpec
