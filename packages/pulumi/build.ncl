let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.254.0" in
{
  name = "pulumi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pulumi/pulumi/v%{version}.tar.gz",
      sha256 = "dfec607f9030b48a405ba847820a786ebbef615526ca646e27d44b33be2757df",
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
