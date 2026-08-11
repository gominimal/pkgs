let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.51.0" in
{
  name = "syft",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/anchore/syft/v%{version}.tar.gz",
      sha256 = "d48bca3091ec4862f5041af6cbdeedb3f2322ae7a059199a22d99e099cabd4ae",
      extract = true,
      strip_prefix = "syft-%{version}",
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
    syft = { glob = "usr/bin/syft" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "syft",
      source_provenance = {
        category = 'GithubRepo,
        owner = "anchore",
        repo = "syft",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
