let { Attrs, BuildSpec, Local, Needs, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.11.30" in
{
  name = "uv",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/uv-%{version}.tar.gz",
      sha256 = "ff895fff1c218fcad67b5b7de829df6d868e677ff34a39d3d0c49a9754247db6"
    } | Source,
    base,
    make,
    rust,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    minimal = { glob = "usr/bin/uv" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      env_state_wiring = {
        env_var = "UV_CACHE_DIR",
        prefix = "uv-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "astral-sh",
        repo = "uv",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
