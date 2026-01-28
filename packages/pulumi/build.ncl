let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.217.1" in
{
  name = "pulumi",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/pulumi/pulumi/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7d10029e848027cf876afe5d809aed37edcf20109e2852083d2d15f7606a29ac",
      extract = true,
      strip_prefix = "pulumi-%{version}",
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
    pulumi = { glob = "usr/bin/pulumi" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "pulumi",
    } | Attrs,
} | BuildSpec
