let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.21.1" in
{
  name = "gopls",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/golang/tools/archive/refs/tags/gopls/v%{version}.tar.gz",
      sha256 = "af211e00c3ffe44fdf2dd3efd557e580791e09f8dbb4284c917bd120bc3c8f9c",
      extract = true,
      strip_prefix = "tools-gopls-v%{version}",
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    go,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    gopls = { glob = "usr/bin/gopls" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "golang",
        repo = "tools",
      },
    } | Attrs,
} | BuildSpec
