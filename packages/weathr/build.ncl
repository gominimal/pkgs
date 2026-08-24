let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.0" in
{
  name = "weathr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Veirt/weathr/v%{version}.tar.gz",
      sha256 = "aa940326f41b23db192165f831567656ea50eb73c971519cbc83adc6d3a21908",
      extract = true,
      strip_prefix = "weathr-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    weathr = { glob = "usr/bin/weathr" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Veirt",
        repo = "weathr",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
