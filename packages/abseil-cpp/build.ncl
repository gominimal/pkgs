let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let patch = import "../patch/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "20260817.0" in
{
  name = "abseil-cpp",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "abseil-cpp-gcc15-bmi2intrin.patch" } | Local,
    {
      url = "https://github.com/abseil/abseil-cpp/releases/download/%{version}/abseil-cpp-%{version}.tar.gz",
      sha256 = "f7e05179df39c45434cad433f5783840bb3788ef322976f9138bc6b72b3a107d",
      extract = true,
      strip_prefix = "abseil-cpp-%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    patch,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    libabsl = { glob = "usr/lib/libabsl*.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/absl/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "abseil",
        repo = "abseil-cpp",
      },
    } | Attrs,
} | BuildSpec
