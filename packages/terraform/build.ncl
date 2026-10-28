let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.17.0" in
{
  name = "terraform",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/hashicorp/terraform/v%{version}.tar.gz",
      sha256 = "ce6ab8d9f28287e51ee1a911417c3c5db4f84e2908084b52d223388e5acf7068",
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
