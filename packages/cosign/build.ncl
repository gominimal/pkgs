let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.4" in
{
  name = "cosign",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sigstore/cosign/v%{version}.tar.gz",
      sha256 = "8096c07e9a3ae21fa600c19cc8ff8c6f15b027184858d0bc0edde5f74589a01a",
      extract = true,
      strip_prefix = "cosign-%{version}",
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
    cosign = { glob = "usr/bin/cosign" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "cosign",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sigstore",
        repo = "cosign",
      },
    } | Attrs,
} | BuildSpec
