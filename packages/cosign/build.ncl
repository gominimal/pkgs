let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.6" in
{
  name = "cosign",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sigstore/cosign/v%{version}.tar.gz",
      sha256 = "ea2f4094d944d79671784ba3d7601d7fdf78c15b0d92cdc4ca31b4d5cff3cd89",
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
      license_spdx = "Apache-2.0",
      repology_project = "cosign",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sigstore",
        repo = "cosign",
      },
    } | Attrs,
} | BuildSpec
