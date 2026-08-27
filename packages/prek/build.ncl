let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.4.14" in
{
  name = "prek",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/j178/prek/v%{version}.tar.gz",
      sha256 = "6f0d3615690382d4a1339a81a2ada2330ac5141481eb79459ed8d63026efb9a0",
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
