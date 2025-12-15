let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "78.1" in
{
  name = "icu",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/unicode-org/icu/releases/download/release-%{version}/icu4c-%{version}-sources.tgz",
      sha256 = "6217f58ca39b23127605cfc6c7e0d3475fe4b0d63157011383d716cb41617886",
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
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "icu",
  } | Attrs,
} | BuildSpec
