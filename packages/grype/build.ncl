let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.115.0" in
{
  name = "grype",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/anchore/grype/v%{version}.tar.gz",
      sha256 = "146d944636f0d6ebfe21a1287306ef742a2d495e5cf629c1bbd47b7515164165",
      extract = true,
      strip_prefix = "grype-%{version}",
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
    grype = { glob = "usr/bin/grype" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "grype",
      source_provenance = {
        category = 'GithubRepo,
        owner = "anchore",
        repo = "grype",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
