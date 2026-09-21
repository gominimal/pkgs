let { BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "4.2.4" in
{
  name = "helm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/helm/helm/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f1a1aa56fff071cfa1eecc18c6a7212b2e5c7a0a123fd8e4dcae620bd51b4286",
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
} | BuildSpec
