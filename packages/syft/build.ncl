let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.41.2" in
{
  name = "syft",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/anchore/syft/v%{version}.tar.gz",
      sha256 = "29377f383cc262113188bdd373899e7c7f7aa73cb5c5cca81fdf2ee0658c603f",
      extract = true,
      strip_prefix = "syft-%{version}",
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
    syft = { glob = "usr/bin/syft" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "syft",
    } | Attrs,
} | BuildSpec
