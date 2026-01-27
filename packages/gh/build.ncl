let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "2.86.0" in
{
  name = "gh",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cli/cli/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "cd2998310e81727af5c2056e9936e6541a20f968d6e3a4891f7fedbc0b336008",
      extract = true,
      strip_prefix = "cli-%{version}",
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

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    gh = { glob = "usr/bin/gh" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "gh",
    } | Attrs,
} | BuildSpec
