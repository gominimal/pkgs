let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let curl = import "../curl/build.ncl" in
let hwdata = import "../hwdata/build.ncl" in
let pciutils = import "../pciutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "b7951" in
{
  name = "llama.cpp",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ggml-org/llama.cpp/archive/refs/tags/%{version}.tar.gz",
      sha256 = "c64f851e2d661acf763e00a98fcdc0d6c7c04ba8b19347d912e108e2a5e23ebc",
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
    subsetOf gcc ["libgcc", "libstdcpp", "libgomp"],
  ],
  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
