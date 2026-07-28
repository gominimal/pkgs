let { subsetOf, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.45.0" in
{
  name = "ast-grep",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ast-grep/ast-grep/archive/refs/tags/%{version}.tar.gz",
      sha256 = "996e9d879f095d3ccef55754d3a32d61e1ae03cfaecdcff5e247bfa5b649b27a",
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
} | BuildSpec
