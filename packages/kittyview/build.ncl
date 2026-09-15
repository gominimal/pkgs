let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.5" in
{
  name = "kittyview",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/gominimal/kittyview/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "8e234b41d31d1aae4fef8d2976420cd58a9727dee6edb80248e7c78ebce8d59e",
      extract = true,
      strip_prefix = "kittyview-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    kittyview = { glob = "usr/bin/kittyview" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "gominimal",
        repo = "kittyview",
      },
    } | Attrs,
} | BuildSpec
