let { Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.1.0" in
{
  name = "tree-sitter-vimdoc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/neovim/tree-sitter-vimdoc/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "020e8f117f648c8697fca967995c342e92dbd81dab137a115cc7555207fbc84f",
      extract = true,
      strip_prefix = "tree-sitter-vimdoc-%{version}",
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
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "neovim",
        repo = "tree-sitter-vimdoc",
      },
    } | Attrs,
} | BuildSpec
