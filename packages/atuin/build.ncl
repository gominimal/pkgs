let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "18.19.0" in
{
  name = "atuin",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/atuinsh/atuin/v%{version}.tar.gz",
      sha256 = "fdb8268cdd5b13105db79e821f06c1c6624e0c5aee46befb0491e39af42fd4e6",
      extract = true,
      strip_prefix = "atuin-%{version}",
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
    atuin = { glob = "usr/bin/atuin" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "atuinsh",
        repo = "atuin",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
