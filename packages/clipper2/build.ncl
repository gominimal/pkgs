let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "2.0.1" in
{
  name = "clipper2",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/AngusJohnson/Clipper2/Clipper2_%{version}.tar.gz",
      sha256 = "2a3693aceab4aed3e39b743e038d87701acc53cf05ed7b2013aab3e0aec5287e",
      extract = true,
      strip_prefix = "Clipper2-Clipper2_%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    libclipper2 = { glob = "usr/lib/libClipper2*{.so*,.a}" } | OutputLib,

    includes = { glob = "usr/include/clipper2/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/clipper2/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "clipper2",
    } | Attrs,
} | BuildSpec
