let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.25.10" in
{
  name = "tree-sitter",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tree-sitter/tree-sitter/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "ad5040537537012b16ef6e1210a572b927c7cdc2b99d1ee88d44a7dcdc3ff44c",
      extract = true,
      strip_prefix = "tree-sitter-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libtree-sitter.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tree-sitter",
        repo = "tree-sitter",
      },
    } | Attrs,
} | BuildSpec
