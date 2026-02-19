let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.9.1" in
{
  name = "duf",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/muesli/duf/v%{version}.tar.gz",
      sha256 = "1334d8c1a7957d0aceebe651e3af9e1c1e0c6f298f1feb39643dd0bd8ad1e955",
      extract = true,
      strip_prefix = "duf-%{version}",
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

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    duf = { glob = "usr/bin/duf" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "duf",
      source_provenance = {
        category = 'GithubRepo,
        owner = "muesli",
        repo = "duf",
      },
    } | Attrs,
} | BuildSpec
