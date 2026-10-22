let { BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "4.3.1" in
{
  name = "helm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/helm/helm/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "e7b803b6a248c18aea067dbccacaf651c29946db75d05fb23f318ff2f15961c6",
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
