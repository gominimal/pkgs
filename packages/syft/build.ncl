let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.41.0" in
{
  name = "syft",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/anchore/syft/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "dedd79d1739833b31cf18b5b082dbf58fd62ebe7dd36b465fed95d6bc9987268",
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
