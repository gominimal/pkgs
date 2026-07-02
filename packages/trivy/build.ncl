let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.72.0" in
{
  name = "trivy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/aquasecurity/trivy/v%{version}.tar.gz",
      sha256 = "2c6e0e5a4b1b08241aab8e379155dfb31855a50cb1d04fa790039cf3010477cf",
      extract = true,
      strip_prefix = "trivy-%{version}",
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
    trivy = { glob = "usr/bin/trivy" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "trivy",
      source_provenance = {
        category = 'GithubRepo,
        owner = "aquasecurity",
        repo = "trivy",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
