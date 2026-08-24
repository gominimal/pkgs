let { subsetOf, Attrs, BuildSpec, Local, OutputData, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-language-server = import "../bash-language-server/build.ncl" in
let eslint = import "../eslint/build.ncl" in
let ghc = import "../ghc/build.ncl" in
let gopls = import "../gopls/build.ncl" in
let haskell-language-server = import "../haskell-language-server/build.ncl" in
let jdtls = import "../jdtls/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let lua-language-server = import "../lua-language-server/build.ncl" in
let nickel-lsp = import "../nickel-lsp/build.ncl" in
let pyright = import "../pyright/build.ncl" in
let ruby-lsp = import "../ruby-lsp/build.ncl" in
let ruff = import "../ruff/build.ncl" in
let rust = import "../rust/build.ncl" in
let typescript-language-server = import "../typescript-language-server/build.ncl" in
let zig = import "../zig/build.ncl" in
let zls = import "../zls/build.ncl" in
{
  name = "dev-language-servers",
  # Meta-package: a batteries-included language-server roster for
  # editor-agnostic LSP setups (emacs/eglot, helix, neovim, ...).
  # Twelve languages: Go, Rust, Python (pyright + ruff), TypeScript/JS
  # (+ eslint), Bash, C/C++, Nickel, Java, Ruby, Lua, Zig, Haskell.
  #
  # The emacs-site-lisp can use these packages
  build_deps = [
    { file = "build.sh" } | Local,
    base,
  ],

  runtime_deps = [
    bash-language-server,
    eslint,
    ghc,
    gopls,
    haskell-language-server,
    jdtls,
    # Only clangd from llvm (the full package is a whole compiler suite),
    # plus the two shared libraries it links (`ldd clangd`): libLLVM.so
    # (llvm is built with LLVM_LINK_LLVM_DYLIB=ON) and libclang-cpp.so.
    subsetOf llvm ["clangd", "libclang", "libllvm"],
    lua-language-server,
    nickel-lsp,
    pyright,
    ruby-lsp,
    ruff,
    rust,
    typescript-language-server,
    zig,
    zls,
  ],

  cmd = "./build.sh",

  outputs = {
    doc = { glob = "usr/share/doc/dev-language-servers/**" } | OutputData,
  },

  attrs =
    {
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
