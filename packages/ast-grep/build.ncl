let { subsetOf, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.42.1" in
{
  name = "ast-grep",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ast-grep/ast-grep/archive/refs/tags/%{version}.tar.gz",
      sha256 = "3e5f6825e4ebb87d0bcd8375c4f9f0d8c158b89e96b1140035b88dc152f92999",
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
    source_provenance = {
      category = 'GithubRepo,
      owner = "ast-grep",
      repo = "ast-grep",
    },
  },
} | BuildSpec
