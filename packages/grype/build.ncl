let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.108.0" in
{
  name = "grype",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/anchore/grype/v%{version}.tar.gz",
      sha256 = "831a9d2e10e43c42974b21364f2f9bc29535d7c447f5ab6677790aa09d9c8d14",
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
      repology_project = "grype",
      source_provenance = {
        category = 'GithubRepo,
        owner = "anchore",
        repo = "grype",
      },
    } | Attrs,
} | BuildSpec
