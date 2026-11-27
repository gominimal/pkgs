let { standaloneTest, subsetOf, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.51.3" in
{
  name = "ast-grep",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ast-grep/ast-grep/archive/refs/tags/%{version}.tar.gz",
      sha256 = "2a40a15fe439f24e24a88d2dd0bd3433a47bbd5032d43f6a4aa2522e397e8def",
      extract = true,
      strip_prefix = "ast-grep-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
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
