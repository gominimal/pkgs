let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.2.0" in
{
  name = "lsd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/lsd-rs/lsd/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "dae8d43087686a4a1de0584922608e9cbab00727d0f72e4aa487860a9cbfeefa",
      extract = true,
      strip_prefix = "lsd-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    lsd = { glob = "usr/bin/lsd" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "lsd-rs",
        repo = "lsd",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
