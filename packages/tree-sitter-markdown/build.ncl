let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Ships two grammars from one repo: block-level (markdown.so) and
# inline-level (markdown_inline.so). Neovim needs both.
let version = "0.5.3" in
{
  name = "tree-sitter-markdown",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-markdown/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "df845b1ab7c7c163ec57d7fa17170c92b04be199bddab02523636efec5224ab6",
      extract = true,
      strip_prefix = "tree-sitter-markdown-%{version}",
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    parsers = { glob = "usr/lib/nvim/parser/*.so" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tree-sitter-grammars",
        repo = "tree-sitter-markdown",
      },
    } | Attrs,
} | BuildSpec
