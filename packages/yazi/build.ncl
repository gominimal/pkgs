let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "26.8.15" in
{
  name = "yazi",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sxyazi/yazi/v%{version}.tar.gz",
      sha256 = "60bd4ca56398f0f6ea6dcf88cc18e325583bf5328aeec51d396070944a9495c8",
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
