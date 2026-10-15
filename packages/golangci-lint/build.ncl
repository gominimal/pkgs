let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.14.0" in
{
  name = "golangci-lint",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golangci/golangci-lint/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f32ec6d5e9ddde780132b808a4ced3de8b5965d99d9771a2b9e68750bb5b0068",
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
