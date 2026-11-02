let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.5.7" in
{
  name = "prek",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/j178/prek/v%{version}.tar.gz",
      sha256 = "c14bfbb5121c24421aea5fbb91a9c835e3e3372e53bdaeb3dedd87cc8eda56b5",
      extract = true,
      strip_prefix = "prek-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    prek = { glob = "usr/bin/prek" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "j178",
        repo = "prek",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
