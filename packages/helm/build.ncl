let { standaloneTest, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "4.3.2" in
{
  name = "helm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/helm/helm/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7d848fa8880cca40f9548e46255d38e3e25259847fe81775c5a09af0c3dda2e1",
      extract = true,
      strip_prefix = "helm-%{version}",
    } | Source,
    base,
    go,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    helm = { glob = "usr/bin/helm" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "helm",
      repo = "helm",
    },
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/helm version",
  },
} | BuildSpec
