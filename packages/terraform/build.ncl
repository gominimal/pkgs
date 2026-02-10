let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.14.4" in
{
  name = "terraform",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/hashicorp/terraform/v%{version}.tar.gz",
      sha256 = "fff97e2a29560e3d5f0b51ce0e6a83eb2fda8bdbe2c083c397d8cb76b3a638e2",
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

  runtime_deps = [
    glibc,
  ],

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
