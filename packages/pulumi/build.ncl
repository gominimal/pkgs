let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.220.0" in
{
  name = "pulumi",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pulumi/pulumi/v%{version}.tar.gz",
      sha256 = "6a48a7cd6747f503b009a0bfdfd257a96288db5c264042c1465a32eb0f0feab9",
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
