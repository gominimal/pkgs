let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.41.1" in
{
  name = "syft",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/anchore/syft/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "d67013800bd0964728384c4450576915bca5758b5c7335e62f22f3f4e399fe90",
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
