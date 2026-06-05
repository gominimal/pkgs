let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.12.2" in
{
  name = "golangci-lint",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golangci/golangci-lint/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "568cfb0ad40832177826608003065a976254415509dd8b4e3ba19ee586388b94",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "golangci",
        repo = "golangci-lint",
      },
    } | Attrs,
} | BuildSpec
