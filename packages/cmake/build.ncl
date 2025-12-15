let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "4.2.1" in
{
  name = "cmake",
  inputs = [
    {
      url = "gs://minimal-staging-archives/cmake-%{version}.tar.gz",
      sha256 = "414aacfac54ba0e78e64a018720b64ed6bfca14b587047b8b3489f407a14a070",
      extract = true,
      strip_prefix = "cmake-%{version}",
    } | Source,
    { file = "build.sh" } | Local,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gcc, # TODO: Only need libstdc++.so.6 and libgcc_s.so1.
    openssl,
  ],

  cmd = "./build.sh",
  outputs = {
    cmake = { glob = "usr/bin/cmake" } | OutputBin,
    cpack = { glob = "usr/bin/cpack" } | OutputBin,
    ctest = { glob = "usr/bin/ctest" } | OutputBin,

    cmake_data = { glob = "usr/share/cmake-*/**" } | OutputData,

    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
    completions = { glob = "usr/share/bash-completion/**/*" } | OutputData,
  },
} | BuildSpec
