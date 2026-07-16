let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

# Pinned to 0.25.x: tree-sitter 0.26 REMOVED `ts_language_version` (renamed to
# `ts_language_abi_version`), which Emacs 30.2's src/treesit.c still calls — so
# a 0.26 bump makes emacs (a reverse-dep in the rebuild closure) FTBFS with
# "implicit declaration of function 'ts_language_version'". The Emacs fix is on
# master (debbugs.gnu.org #79627) but NOT in a release yet, and it makes Emacs
# require tree-sitter >= 0.25. Bump to 0.26 only TOGETHER with an Emacs release
# that ships the #79627 fix (coordinated reverse-dep upgrade).
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
