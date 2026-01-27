let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.14.3" in
{
  name = "terraform",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/hashicorp/terraform/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "63ae0ec6e40a1245dc05f9105f708054405426940cef6bb378dd2150e24bf625",
      extract = true,
      strip_prefix = "terraform-%{version}",
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
    terraform = { glob = "usr/bin/terraform" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "terraform",
    } | Attrs,
} | BuildSpec
