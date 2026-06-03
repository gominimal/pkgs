let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.22.0" in
{
  name = "cloud-sql-proxy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/GoogleCloudPlatform/cloud-sql-proxy/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "03748bca4bfee26c79743c8a1ff90df7daf871a8abf1912e093ec64adf40fcb9",
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
} | BuildSpec
