let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.15.0" in
{
  name = "golangci-lint",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golangci/golangci-lint/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "5411598703f014f1128b209f3d46da6f9f2c99a68783c90f846b4db1c8c08742",
      extract = true,
    } | Source,
    base,
    go,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    golangci-lint = { glob = "usr/bin/golangci-lint" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "golangci",
        repo = "golangci-lint",
      },
    } | Attrs,
} | BuildSpec
