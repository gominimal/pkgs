let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.107.0" in
{
  name = "grype",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/anchore/grype/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "e87c63ab39ebd4b98bbbbfc70ade328747383cc1cc410b9d29edb94b46762c1e",
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
    } | Attrs,
} | BuildSpec
