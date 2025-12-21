let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let hwdata = import "../hwdata/build.ncl" in
let pciutils = import "../pciutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "b7499" in
{
  name = "llama.cpp",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ggml-org/llama.cpp/archive/refs/tags/%{version}.tar.gz",
      sha256 = "dd08c9028dd7323554acb3755aa2ff65bd3556b35e4bd780d5cf01ada9824dcc",
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
