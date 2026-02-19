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

let version = "b8041" in
{
  name = "llama.cpp",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ggml-org/llama.cpp/%{version}.tar.gz",
      sha256 = "3d3015ce8326b22024e8d833be996f82c6444b232a804b2b983bf6e57ba65a2e",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "ggml-org",
        repo = "llama.cpp",
      },
    } | Attrs,
} | BuildSpec
