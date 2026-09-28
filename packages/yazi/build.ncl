let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "26.9.1" in
{
  name = "yazi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sxyazi/yazi/v%{version}.tar.gz",
      sha256 = "66857f1b670469daf258edd0bb2ea51d9ad3e2cab4eea9684028c80059fd6862",
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
  # Surfaces `version` to build.sh as MINIMAL_ARG_VERSION, which stamps the
  # build-time VERGEN_GIT_SHA yazi-version demands (no git in the sandbox).
  build_args = {
    include version,
  },

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
