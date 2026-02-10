let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let clipper2 = import "../clipper2/build.ncl" in
let onetbb = import "../onetbb/build.ncl" in

let version = "3.3.2" in
{
  name = "manifold",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/elalish/manifold/v%{version}.tar.gz",
      sha256 = "92a37034c407156f71446f9ca03bd4487adeb1b8246a03d1c047b859b1b9d211",
      extract = true,
      strip_prefix = "manifold-%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    clipper2,
    onetbb,
  ],

  cmd = "./build.sh",
  outputs = {
    libmanifold = { glob = "usr/lib/libmanifold*.so*" } | OutputLib,

    includes = { glob = "usr/include/manifold/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/manifold/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "manifold-geometry-library",
    } | Attrs,
} | BuildSpec
