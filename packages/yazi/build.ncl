let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "26.5.6" in
{
  name = "yazi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sxyazi/yazi/v%{version}.tar.gz",
      sha256 = "a18445df86a20068f7b17609d12d6f635de488958579ae7a2b143a244ba7e63f",
      extract = true,
      strip_prefix = "yazi-%{version}",
    } | Source,
    base,
    rust,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    yazi = { glob = "usr/bin/yazi" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "yazi",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sxyazi",
        repo = "yazi",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
