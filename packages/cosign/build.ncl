let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.1.3" in
{
  name = "cosign",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sigstore/cosign/v%{version}.tar.gz",
      sha256 = "ab8fcb8e0b4c0b8d01aefa37790cdd5ad099366b2efb8636b7a0250915b93362",
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
