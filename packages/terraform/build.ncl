let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.15.8" in
{
  name = "terraform",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/hashicorp/terraform/v%{version}.tar.gz",
      sha256 = "7dcc43701dc10c2dfdd3704eb5c910337c858e2565417a7fe15430508938c2c0",
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
      license_spdx = "BUSL-1.1",
      repology_project = "terraform",
      source_provenance = {
        category = 'GithubRepo,
        owner = "hashicorp",
        repo = "terraform",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
