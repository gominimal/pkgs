let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let emacs = import "../emacs/build.ncl" in
let git = import "../git/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
{
  name = "emacs-site-lisp",
  # Library-only elisp + tree-sitter grammars for the MPR emacs package.
  #
  # Successor to the library half of emacs-config-dev1: every elisp package
  # and grammar is a sha256-pinned release tarball, byte-compiled at build
  # time. Unlike emacs-config-dev1 this package ships NO minimal-init-*
  # fragment: installing it only extends load-path (via the emacs package's
  # site-start.el). Nothing is enabled until a user's own init requires it,
  # so it composes with any personal config without forcing behavior.
  build_deps = [
    { file = "build.sh" } | Local,

    # ── Completion framework ───────────────────────────────────────────
    {
      url = "https://github.com/minad/vertico/archive/refs/tags/2.12.tar.gz",
      sha256 = "fc7f2a3a9935088579d60dacdb5e598d2410b18a6bacebea19d39c695d0d0163",
      extract = true,
    } | Source,
    {
      url = "https://github.com/oantolin/orderless/archive/refs/tags/1.7.tar.gz",
      sha256 = "5b6d24c8a863073d1922908e6f2f9a92bad73bee8fb2c2a813ea1fc64d3eb5c7",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/marginalia/archive/refs/tags/2.11.tar.gz",
      sha256 = "705ca7aa21706e0e78e1d7e8afed566f322f4bc0c7d305e2a2839558efdb5dc2",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/consult/archive/refs/tags/3.7.tar.gz",
      sha256 = "497aa8dcdca0fb8ce4ac0838d13ddc667dd4902be5802937f97c29e0a74c5793",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/corfu/archive/refs/tags/2.13.tar.gz",
      sha256 = "9789fa4f223bd75f518f33ef0ee05990b010724966e19004896f2b07e302e166",
      extract = true,
    } | Source,
    {
      url = "https://github.com/minad/cape/archive/refs/tags/2.8.tar.gz",
      sha256 = "9c6022851de1163abbd05904d2925b63de5313a0e94f1379cd78f64eb484db29",
      extract = true,
    } | Source,
    {
      url = "https://github.com/oantolin/embark/archive/refs/tags/1.2.tar.gz",
      sha256 = "6a9ba6c7adddbf2c2e92dec7026cfc25b179d50f10418d5de8e7f4c72be4548b",
      extract = true,
    } | Source,

    # ── Corfu terminal rendering (emacs is built --without-x) ──────────
    {
      url = "https://codeberg.org/akib/emacs-corfu-terminal/archive/v0.7.tar.gz",
      sha256 = "88402635bf4d967dba0238baed5a2a6a370591c730d6ba05de2be4680d33e334",
      extract = true,
    } | Source,
    {
      url = "https://codeberg.org/akib/emacs-popon/archive/v0.13.tar.gz",
      sha256 = "5f7c3d31dd69370db031ebacb45432daa3dcce7827d9a77783772ed1d94c5978",
      extract = true,
    } | Source,

    # ── Editable grep buffers ──────────────────────────────────────────
    {
      url = "https://github.com/mhayashi1120/Emacs-wgrep/archive/refs/tags/3.0.0.tar.gz",
      sha256 = "034d5ceeff43ffe30a556f922232f356355e0bf9b89126ff218c1893bb0dd1d0",
      extract = true,
    } | Source,

    # ── Magit and dependencies ─────────────────────────────────────────
    {
      url = "https://github.com/emacs-compat/compat/archive/refs/tags/31.0.0.2.tar.gz",
      sha256 = "bbbf48ac8964425c09a6d3b7abe2ae9ff95fb9e43154f252977290f1de79aab9",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tarsius/llama/archive/refs/tags/v1.0.5.tar.gz",
      sha256 = "7194b803d05cc1b260fcae932b1884a06c61dc327a92d4986a1f91f35b08abdb",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tarsius/cond-let/archive/refs/tags/v1.1.3.tar.gz",
      sha256 = "ce631fbd9a0f16d00db54e6cb13b77f1fb9a423cc37e1aba6339d7dfc630e7fe",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magit/transient/archive/refs/tags/v0.13.7.tar.gz",
      sha256 = "7ae2bbfd073a34d8d8a0510473d55f917529ec5c13b86da5318b22e485c31555",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magit/with-editor/archive/refs/tags/v3.5.3.tar.gz",
      sha256 = "12f30b6356235962e91f38897413f0c65a981cfbf6b9f699efa3aa2636443adc",
      extract = true,
    } | Source,
    {
      url = "https://github.com/magit/magit/archive/refs/tags/v4.7.0.tar.gz",
      sha256 = "9baddf75339eeccce22dae0cd59c43bbdfc0b2e5745422063858492f341ecb75",
      extract = true,
    } | Source,

    # ── Language modes without a built-in ts-mode ──────────────────────
    {
      url = "https://github.com/jrblevin/markdown-mode/archive/refs/tags/v2.8.tar.gz",
      sha256 = "8252904252f771019c0b17e38be07cc8893e39da50e58dc5142dca50b0dd2dee",
      extract = true,
    } | Source,
    {
      url = "https://github.com/nickel-lang/nickel-mode/archive/e2dcd6cf66d9b5bcde3e3cd69efe053f73b081ab.tar.gz",
      sha256 = "209d5129ea006d0a335fbf82221878a6aa4796d18b048ce895d18473bc7d65a4",
      extract = true,
    } | Source,
    # reformatter is a hard dependency of zig-mode ((require 'reformatter)
    # at load time, for zig-format); it only needs the built-in ansi-color.
    {
      url = "https://github.com/purcell/emacs-reformatter/archive/refs/tags/0.7.tar.gz",
      sha256 = "dc5b0a569840e9c132d4f05421aef820bb5ec19b3457d3be3461c8c64137b7bc",
      extract = true,
    } | Source,
    {
      url = "https://github.com/ziglang/zig-mode/archive/66490933a468b5d55a90645c4c87067c508ccd04.tar.gz",
      sha256 = "c69cc953292f029924a007738bcf56a0d8e729e42b4274182cb70c804e876f5b",
      extract = true,
    } | Source,
    {
      url = "https://codeberg.org/pranshu/haskell-ts-mode/archive/bf143ee8382f09e0a68d775d80445065f32929c3.tar.gz",
      sha256 = "7e6bf2e4039a5b66ccfac8f7f3c010ade7d193caf8fd8568c26d1d9e2c629465",
      extract = true,
    } | Source,

    # ── Extra flymake backends ─────────────────────────────────────────
    {
      url = "https://github.com/erickgnavar/flymake-ruff/archive/ef4a6caed72bce77a27bda54ffb30e3fdb0e7d76.tar.gz",
      sha256 = "8302058f4f5609769244e36f2c9b8d31a119d117a1d20d7fb933a2ed46e0c117",
      extract = true,
    } | Source,
    {
      url = "https://github.com/orzechowskid/flymake-eslint/archive/refs/tags/1.5.0.tar.gz",
      sha256 = "c7bee8fadaea088fc2d3bf7ec91bbd79116fbbf111e06d1e013284a5819c9667",
      extract = true,
    } | Source,

    # ── Tree-sitter grammars ───────────────────────────────────────────
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
    {
      url = "https://github.com/tree-sitter/tree-sitter-java/archive/refs/tags/v0.23.5.tar.gz",
      sha256 = "cb199e0faae4b2c08425f88cbb51c1a9319612e7b96315a174a624db9bf3d9f0",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-ruby/archive/refs/tags/v0.23.1.tar.gz",
      sha256 = "e7e49577ddc1f2de8e42d42353b477e338c15bbb95b2558e123ddc13d88789f0",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-lua/archive/refs/tags/v0.5.0.tar.gz",
      sha256 = "cf01b93f4b61b96a6d27942cf28eeda4cbce7d503c3bef773a8930b3d778a2d9",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter-grammars/tree-sitter-zig/archive/refs/tags/v1.1.2.tar.gz",
      sha256 = "612d67059faa90ec7691e5d786d70d8f7c2c8b15b83de901b9b801122ad4cf25",
      extract = true,
    } | Source,
    {
      url = "https://github.com/tree-sitter/tree-sitter-haskell/archive/refs/tags/v0.23.1.tar.gz",
      sha256 = "bac7d0a37730af62d883e2bdbafb68f47e7ab4f5e744c7586bffc589906a8cc2",
      extract = true,
    } | Source,
    {
      url = "https://github.com/camdencheek/tree-sitter-dockerfile/archive/refs/tags/v0.2.0.tar.gz",
      sha256 = "8cbdf50838cc55e841aa9585a1a09e5b8c41454ae30ce0a93a7bd71adb140818",
      extract = true,
    } | Source,
    base,
    emacs,
    toolchain,
  ],

  runtime_deps = [
    emacs,
  ],

  cmd = "./build.sh",

  outputs = {
    site-lisp = { glob = "usr/share/emacs/site-lisp/**" } | OutputData,
    grammars = { glob = "usr/lib/emacs/tree-sitter/*.so" } | OutputLib,
  },

  tests = {
    # git: magit runs `git version` from its startup assert as soon as it is
    # required in batch mode (after-init-time is set by then), so loading it
    # needs a git on PATH. base: coreutils for the emacs wrapper's mkdir.
    libs-loadable =
      {
        class = 'Standalone,
        test_deps = [base, git],
        cmds = [
          ["emacs", "--batch", "--eval", "(progn (require 'vertico) (require 'orderless) (require 'marginalia) (require 'consult) (require 'corfu) (require 'corfu-terminal) (require 'cape) (require 'embark) (require 'wgrep) (require 'magit) (require 'markdown-mode) (require 'nickel-mode) (require 'zig-mode) (require 'haskell-ts-mode) (require 'flymake-ruff) (require 'flymake-eslint))"],
        ],
      } | Test,

    # corfu-terminal must still LOAD and its mode must switch on. This is a
    # load smoke test, not a patch guard: the early-defvar patch it used to
    # guard was removed at the 31.1 bump (see build.sh), because 31.1 emits no
    # "reference to free variable `corfu-terminal-mode'" warning even without
    # it — verified by disabling the patch and inspecting the real output.
    #
    # It deliberately does not assert "no warnings": corfu emits an
    # informational "`corfu-terminal' is not needed on Emacs 31", which says
    # nothing about whether the package loads. That notice is worth acting on
    # separately — but it keys on the Emacs VERSION, and our emacs is built
    # --without-x, so 31 having TTY child frames does not prove OUR build does.
    # Verify terminal completion works without corfu-terminal in a real TTY
    # before dropping the package itself.
    corfu-terminal-loads-cleanly =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval \"(progn (require 'corfu-terminal) (corfu-terminal-mode 1) (message \\\"corfu-terminal-mode=%s\\\" corfu-terminal-mode))\" 2>&1 | grep -q 'corfu-terminal-mode=t'"],
        ],
      } | Test,

    # End-to-end font-lock through a bundled grammar: go-ts-mode's builtin
    # feature uses a :match predicate, which libtree-sitter >= 0.26 only
    # accepts in the form the emacs package's treesit-predicates-0.26.patch
    # emits. Fontify a sample at level 4 and require real faces and no
    # treesit-query-error.
    go-ts-font-lock =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf 'package main\\n\\nimport \"fmt\"\\n\\nfunc main() {\\n\\tx := append([]int{}, 1)\\n\\tfmt.Println(\"hi\", x)\\n}\\n' > /tmp/t.go; out=$(emacs --batch --eval '(progn (add-to-list (quote treesit-extra-load-path) \"/usr/lib/emacs/tree-sitter\") (setq treesit-font-lock-level 4) (find-file \"/tmp/t.go\") (go-ts-mode) (font-lock-ensure) (let (faces) (goto-char (point-min)) (while (not (eobp)) (let ((f (get-text-property (point) (quote face)))) (when f (push f faces))) (forward-char)) (princ (format \"faces=%S\" (delete-dups faces)))))' 2>&1 | grep -v 'newer than byte-compiled'); echo \"$out\"; echo \"$out\" | grep -q 'font-lock-builtin-face' && echo \"$out\" | grep -q 'font-lock-keyword-face' && ! echo \"$out\" | grep -q 'treesit-query-error'"],
        ],
      } | Test,
  },

  attrs =
    {
      # Aggregate: elisp is GPL-3.0-or-later; bundled tree-sitter grammars are MIT.
      license_spdx = "GPL-3.0-or-later",
    } | Attrs,
} | BuildSpec
