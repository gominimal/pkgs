let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.69.1" in
{
  name = "trivy",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/aquasecurity/trivy/v%{version}.tar.gz",
      sha256 = "997f7b744e93bd2faa9f0c2f86345ab142d50d42a6ed2b3a35dc8b65676355ee",
      extract = true,
      strip_prefix = "trivy-%{version}",
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
    trivy = { glob = "usr/bin/trivy" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "trivy",
    } | Attrs,
} | BuildSpec
