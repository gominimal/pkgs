let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.53.6" in
{
  name = "yq",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/mikefarah/yq/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "132a28a669526f99dba52486ac80de3bdafdf9a1a52a0c6bd6045301aca0cd25",
      extract = true,
      strip_prefix = "yq-%{version}",
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
    yq = { glob = "usr/bin/yq" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "mikefarah",
        repo = "yq",
      },
    } | Attrs,
} | BuildSpec
