let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.68.2" in
{
  name = "trivy",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/aquasecurity/trivy/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "dd8efd719709d09b41c98cdb9090654f8ed326f07b05ba7a4ffca4de2745aea3",
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
