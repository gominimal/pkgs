let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let clipper2 = import "../clipper2/build.ncl" in
let onetbb = import "../onetbb/build.ncl" in

let version = "3.4.0" in
{
  name = "manifold",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/elalish/manifold/manifold-%{version}.tar.gz",
      sha256 = "03fb429c2080363cadc6e9a34ecd6ba7948c74d99baffb3df381546effaa6907",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "elalish",
        repo = "manifold",
      },
    } | Attrs,
} | BuildSpec
