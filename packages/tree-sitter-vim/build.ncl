let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.8.1" in
{
  name = "tree-sitter-vim",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-vim/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "93cafb9a0269420362454ace725a118ff1c3e08dcdfdc228aa86334b54d53c2a",
      extract = true,
      strip_prefix = "tree-sitter-vim-%{version}",
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
        owner = "tree-sitter-grammars",
        repo = "tree-sitter-vim",
      },
    } | Attrs,
} | BuildSpec
