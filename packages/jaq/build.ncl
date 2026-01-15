let { subsetOf, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.3.0" in
{
  name = "jaq",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/01mf02/jaq/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "80fae7c5bbbc244580ca77d3e5a4fc6e9c3ea08a5526d562e3c5300edd44fe8b",
      extract = true,
      strip_prefix = "jaq-%{version}",
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
    jaq = { glob = "usr/bin/jaq" } | OutputLib,
  },
  attrs.upstream_version = version,
} | BuildSpec
