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

let version = "b10141" in
{
  name = "llama.cpp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ggml-org/llama.cpp/%{version}.tar.gz",
      sha256 = "1397f057a413b5f8c9bc2cc4083d8348b88efdcbbf820f2bb57a5d2245fb2f8c",
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
    llama-server = { glob = "usr/bin/llama-server" } | OutputBin,
    llama-cli = { glob = "usr/bin/llama-cli" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ggml-org",
        repo = "llama.cpp",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
