let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "18.17.1" in
{
  name = "atuin",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/atuinsh/atuin/v%{version}.tar.gz",
      sha256 = "851c3f4870e4bd181b98d2dae60b9fd76ef30f05f16a85efa21ac7e7cf294862",
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
