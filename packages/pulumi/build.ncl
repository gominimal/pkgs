let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.253.0" in
{
  name = "pulumi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pulumi/pulumi/v%{version}.tar.gz",
      sha256 = "6bffd86f18ebeefbba91ca747822b1b8eb418f8c85e800fce0535d9e1b2310f0",
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
    pulumi-language-go = { glob = "usr/bin/pulumi-language-go" } | OutputBin,
    pulumi-language-nodejs = { glob = "usr/bin/pulumi-language-nodejs" } | OutputBin,
    pulumi-language-python = { glob = "usr/bin/pulumi-language-python" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "pulumi",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pulumi",
        repo = "pulumi",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
