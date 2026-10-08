let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.75.0" in
{
  name = "trivy",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/aquasecurity/trivy/v%{version}.tar.gz",
      sha256 = "4ee2010384f90bf23d4059ae49c11129e5041816a3754d890a90ae80f678d765",
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
