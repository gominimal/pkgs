let { standaloneTest, subsetOf, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.51.1" in
{
  name = "ast-grep",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ast-grep/ast-grep/archive/refs/tags/%{version}.tar.gz",
      sha256 = "a9cb3f5cac1c0d22df189117df8d78fa3d7e9fdcd83fb5b6ab1f0b66c8835a55",
      extract = true,
      strip_prefix = "ast-grep-%{version}",
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
    bins = { glob = "usr/bin/ast-grep" } | OutputBin,
  },

  needs = {
    internet = {},
  },

  attrs = {
    upstream_version = version,
    license_spdx = "MIT",
    source_provenance = {
      category = 'GithubRepo,
      owner = "ast-grep",
      repo = "ast-grep",
    },
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/ast-grep --version",
  },
} | BuildSpec
