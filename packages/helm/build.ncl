let { BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let version = "4.2.3" in
{
  name = "helm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/helm/helm/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "9ca555fa3777082fd646c95abf4ee17fc31e25ba97bad76da9de1df2332be168",
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
