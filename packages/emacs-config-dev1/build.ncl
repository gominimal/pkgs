let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-language-server = import "../bash-language-server/build.ncl" in
let emacs = import "../emacs/build.ncl" in
let git = import "../git/build.ncl" in
let gopls = import "../gopls/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let nickel-lsp = import "../nickel-lsp/build.ncl" in
let pyright = import "../pyright/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let tree-sitter = import "../tree-sitter/build.ncl" in
let typescript-language-server = import "../typescript-language-server/build.ncl" in
{
  name = "emacs-config-dev1",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "init.el" } | Local,

    # ── Completion framework ───────────────────────────────────────────
    {
      url = "https://github.com/minad/vertico/archive/refs/tags/2.8.tar.gz",
      sha256 = "b6b97cff92563ccd476b46d37a2d74239af5e6219ebbc30ac21e376fae30daf1",
      extract = true,
    } | Source,
    {
      url = "https://github.com/oantolin/orderless/archive/refs/tags/1.6.tar.gz",
      sha256 = "7d6d8ace8041bc179e6d25bd901909cb7d3c9f44dc9fa453bbd46094c7d86588",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/marginalia/archive/refs/tags/2.10.tar.gz",
      sha256 = "0fbe3f182cebb7850527ee22a898c95e7145ecabb304886f8cc791f8ff21ff04",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/consult/archive/refs/tags/3.4.tar.gz",
      sha256 = "22da07c49234516289307e1e6feab03785f9db75859088c197cbc219e7196f53",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/corfu/archive/refs/tags/2.9.tar.gz",
      sha256 = "4144b729ea2712921a1ca35b6178fd06eb20d544508c0c105afcfdf22d242a38",
      extract = true,
    } | Source,

    # ── Which-key ──────────────────────────────────────────────────────
    {
      url = "https://github.com/justbur/emacs-which-key/archive/refs/tags/v3.6.0.tar.gz",
      sha256 = "b97a90c6db113d29b6404c0f29e240555d0b67c8cfc464fa04b05cdc38540e4f",
      extract = true,
    } | Source,

    # ── Magit and dependencies ─────────────────────────────────────────
    {
      url = "https://github.com/emacs-compat/compat/archive/refs/tags/30.1.0.1.tar.gz",
      sha256 = "ed424d15e462acd47fd58f5e86047d72393124063dc12841ee441aa0ac643f9a",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magnars/dash.el/archive/refs/tags/2.20.0.tar.gz",
      sha256 = "77ca899620594a0e862863f03c137fcdf4551133697301cb712b200e80ee44c4",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magit/transient/archive/refs/tags/v0.12.0.tar.gz",
      sha256 = "4253eb2cedb988651f747f9aa953d44d0f5a45c2fca89f9c57ed925ecd5b2a46",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magit/with-editor/archive/refs/tags/v3.4.9.tar.gz",
      sha256 = "47ee6519666d976b16d4624cf349e68e96447ebb20ddf0d5cbb36b51d13b7702",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magit/magit/archive/refs/tags/v4.5.0.tar.gz",
      sha256 = "8f99c6080fb9656606be1dc588b82d9756de1c7461375b0f24f83d0ac09ef413",
      extract = true,
    } | Source,

    # ── Extra modes ────────────────────────────────────────────────────
    {
      url = "https://github.com/jrblevin/markdown-mode/archive/refs/tags/v2.8.tar.gz",
      sha256 = "8252904252f771019c0b17e38be07cc8893e39da50e58dc5142dca50b0dd2dee",
      extract = true,
    } | Source,
    {
      url = "https://github.com/yoshiki/yaml-mode/archive/refs/tags/v0.0.13.tar.gz",
      sha256 = "c547b1ec62e6b39fd3e95e28b8d3918958d4f00391c471485532dbc6cc3dcab8",
      extract = true,
    } | Source,
    {
      url = "https://github.com/spotify/dockerfile-mode/archive/refs/tags/v1.9.tar.gz",
      sha256 = "47ea016b8f6b05d15ba5e12e1773eeca9cea13f79fd73cd44f6873f1f276db0e",
      extract = true,
    } | Source,
    {
      url = "https://github.com/nickel-lang/nickel-mode/archive/e2dcd6cf66d9b5bcde3e3cd69efe053f73b081ab.tar.gz",
      sha256 = "209d5129ea006d0a335fbf82221878a6aa4796d18b048ce895d18473bc7d65a4",
      extract = true,
    } | Source,
    {
      url = "https://github.com/rust-lang/rust-mode/archive/refs/tags/1.0.6.tar.gz",
      sha256 = "37ac9c0e05c915861af3996e037b18cc7d03f52d7fb508af7c404425ac95a461",
      extract = true,
    } | Source,

    # ── Tree-sitter grammars ──────────────────────────────────────────
    {
      url = "https://github.com/tree-sitter/tree-sitter-rust/archive/refs/tags/v0.23.2.tar.gz",
      sha256 = "71ce61738f8aff4531afed443572ca68aa74a66a07569a1d50863eb34787c782",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-go/archive/refs/tags/v0.23.4.tar.gz",
      sha256 = "967870d7d120e9b760e538aeb8331a72f70ffcca4f1eaf1e1dea5375886d25d2",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-typescript/archive/refs/tags/v0.23.2.tar.gz",
      sha256 = "2c4ce711ae8d1218a3b2f899189298159d672870b5b34dff5d937bed2f3e8983",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-python/archive/refs/tags/v0.23.6.tar.gz",
      sha256 = "630a0f45eccd9b69a66a07bf47d1568e96a9c855a2f30e0921c8af7121e8af96",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-bash/archive/refs/tags/v0.23.3.tar.gz",
      sha256 = "c682b81d0fe953d19f6632db3ba6e4f2db1efe1784f7a28bc5fcf6355d67335b",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-c/archive/refs/tags/v0.23.4.tar.gz",
      sha256 = "b66c5043e26d84e5f17a059af71b157bcf202221069ed220aa1696d7d1d28a7a",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-cpp/archive/refs/tags/v0.23.4.tar.gz",
      sha256 = "7a2c55afe3028f4105f25762ea58cc16537d1f5a1dcd9cca90410b3cd5d46051",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-json/archive/refs/tags/v0.24.8.tar.gz",
      sha256 = "acf6e8362457e819ed8b613f2ad9a0e1b621a77556c296f3abea58f7880a9213",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-yaml/archive/refs/tags/v0.7.2.tar.gz",
      sha256 = "aeaff5731bb8b66c7054c8aed33cd5edea5f4cd2ac71654f3f6c2ba2073d8fac",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-toml/archive/refs/tags/v0.7.0.tar.gz",
      sha256 = "7d52a7d4884f307aabc872867c69084d94456d8afcdc63b0a73031a8b29036dc",
      extract = true,
    } | Source,
    {
      url = "https://github.com/camdencheek/tree-sitter-go-mod/archive/refs/tags/v1.1.0.tar.gz",
      sha256 = "66f55e0dfa9d654484146c405261d667196d3b20872fa3f7813d5125a82d6de8",
      extract = true,
    } | Source,
    base,
    emacs,
    toolchain,
  ],

  runtime_deps = [
    bash-language-server,
    subsetOf llvm ["clangd"],
    emacs,
    git,
    gopls,
    nickel-lsp,
    pyright,
    rust,
    tree-sitter,
    typescript-language-server,
  ],

  cmd = "./build.sh",

  outputs = {
    site-lisp = { glob = "usr/share/emacs/site-lisp/**" } | OutputData,
    grammars = { glob = "usr/lib/emacs/tree-sitter/*.so" } | OutputLib,
  },

  attrs =
    {} | Attrs,
} | BuildSpec
