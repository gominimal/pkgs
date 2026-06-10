let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.6.1" in
{
  name = "jnv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ynqa/jnv/v%{version}.tar.gz",
      sha256 = "03223fb20a4c65c2610b94e6208b65098e6b3fe836d3deea75931a5c808f4869",
      extract = true,
      strip_prefix = "jnv-%{version}",
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
    jnv = { glob = "usr/bin/jnv" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "jnv",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ynqa",
        repo = "jnv",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
