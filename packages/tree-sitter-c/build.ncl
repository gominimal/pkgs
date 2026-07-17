let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.24.2" in
{
  name = "tree-sitter-c",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tree-sitter/tree-sitter-c/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2eeb4db31f8fa0865e45488503d13403923bcb485a1bdb637abff8c42dd97364",
      extract = true,
      strip_prefix = "tree-sitter-c-%{version}",
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    parser = { glob = "usr/lib/nvim/parser/*.so" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tree-sitter",
        repo = "tree-sitter-c",
      },
    } | Attrs,
} | BuildSpec
