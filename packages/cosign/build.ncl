let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.1.2" in
{
  name = "cosign",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sigstore/cosign/v%{version}.tar.gz",
      sha256 = "cddaacb84071a1f843bf0d46f02232b35c808f4eadbfe1e0be452069dc03816f",
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
