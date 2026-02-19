let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.14.5" in
{
  name = "terraform",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/hashicorp/terraform/v%{version}.tar.gz",
      sha256 = "ac3faee7b1d301a4d12fe6b7f33b1ba57a183e080a2442f6f1466a30f257ba45",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "hashicorp",
        repo = "terraform",
      },
    } | Attrs,
} | BuildSpec
