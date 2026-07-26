let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gettext = import "../gettext/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let lpeg = import "../lpeg/build.ncl" in
let luajit = import "../luajit/build.ncl" in
let luv = import "../luv/build.ncl" in
let tree-sitter = import "../tree-sitter/build.ncl" in
let tree-sitter-c = import "../tree-sitter-c/build.ncl" in
let tree-sitter-lua = import "../tree-sitter-lua/build.ncl" in
let tree-sitter-markdown = import "../tree-sitter-markdown/build.ncl" in
let tree-sitter-query = import "../tree-sitter-query/build.ncl" in
let tree-sitter-vim = import "../tree-sitter-vim/build.ncl" in
let tree-sitter-vimdoc = import "../tree-sitter-vimdoc/build.ncl" in
let unibilium = import "../unibilium/build.ncl" in
let utf8proc = import "../utf8proc/build.ncl" in

let version = "0.12.4" in
{
  name = "neovim",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/neovim/neovim/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2727da95d2b8b809bc7c71e085452e47dfe1d8aa7cfaa15c68004e23f6f0a6dd",
      extract = true,
      strip_prefix = "neovim-%{version}",
    } | Source,
    base,
    cmake,
    gettext, # msgfmt, for building the locale files
    make, # cmake/Deps.cmake hard-requires GNU Make even for non-bundled builds
    ninja,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    nvim = { glob = "usr/bin/nvim" } | OutputBin,
    data = { glob = "usr/share/**/*" } | OutputData,
  },
  runtime_deps = [
    glibc,
    libuv,
    lpeg,
    luajit,
    luv,
    tree-sitter,
    unibilium,
    utf8proc,
    # The treesitter grammars upstream bundles via cmake.deps, packaged
    # separately here; nvim loads them from usr/lib/nvim/parser/ at runtime.
    tree-sitter-c,
    tree-sitter-lua,
    tree-sitter-markdown,
    tree-sitter-query,
    tree-sitter-vim,
    tree-sitter-vimdoc,
  ],
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0 AND Vim",
      source_provenance = {
        category = 'GithubRepo,
        owner = "neovim",
        repo = "neovim",
      },
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "nvim --version"],
          # Boots the editor headless and exits — verifies the runtime dir
          # (usr/share/nvim/runtime) is found relative to the binary.
          ["/bin/bash", "-c", "nvim --headless +quit"],
          # Verifies a packaged grammar loads from usr/lib/nvim/parser/.
          ["/bin/bash", "-c", "nvim --headless \"+lua assert(vim.treesitter.language.add('c'))\" +quit"],
        ],
      } | Test,
  },
} | BuildSpec
