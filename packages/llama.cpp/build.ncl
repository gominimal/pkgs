let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let hwdata = import "../hwdata/build.ncl" in
let pciutils = import "../pciutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "b7783" in
{
  name = "llama.cpp",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ggml-org/llama.cpp/archive/refs/tags/%{version}.tar.gz",
      sha256 = "47f5accbcb36b14d6f5c058d9e13038a07bcb6f4becc6c6d80dc8342d731d458",
      extract = true,
      strip_prefix = "llama.cpp-%{version}",
    } | Source,
    base,
    git,
    make,
    cmake,
    toolchain,
  ],
  runtime_deps = [
    curl,
    hwdata,
    pciutils,
  ],
  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,
  },

  attrs = {
    upstream_version = version,
  } | Attrs,
} | BuildSpec
