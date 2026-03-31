let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let gnutls = import "../gnutls/build.ncl" in
let jansson = import "../jansson/build.ncl" in
let libxml2 = import "../libxml2/build.ncl" in
let make = import "../make/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let tree-sitter = import "../tree-sitter/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let version = "30.2" in
{
  name = "emacs",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "fixrand.c" } | Local,
    {
      url = "https://ftpmirror.gnu.org/emacs/emacs-%{version}.tar.xz",
      sha256 = "b3f36f18a6dd2715713370166257de2fae01f9d38cfe878ced9b1e6ded5befd9",
      extract = true,
      strip_prefix = "emacs-%{version}",
    } | Source,
    autoconf,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gmp,
    gnutls,
    jansson,
    libxml2,
    ncurses,
    subsetOf gcc ["libgcc"],
    tree-sitter,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libexec = { glob = "usr/libexec/emacs/**", allow_executable = true } | OutputData,
    share = { glob = "usr/share/emacs/**", allow_executable = true } | OutputData,
  },

  tests = {
    version = standaloneTest "/usr/bin/emacs --version",

    batch_eval = {
      class = 'Standalone,
      test_deps = [base],
      cmds = [
        ["/bin/bash", "-c", "emacs --batch --eval '(message \"hello\")' 2>&1 | grep -q hello"],
      ],
    } | Test,

    byte_compile = {
      class = 'Standalone,
      test_deps = [base],
      cmds = [
        ["/bin/bash", "-c", "echo '(defun test-fn () 42)' > /tmp/test.el"],
        ["/bin/bash", "-c", "emacs --batch -f batch-byte-compile /tmp/test.el"],
        ["/bin/bash", "-c", "test -f /tmp/test.elc"],
      ],
    } | Test,

    gnutls = {
      class = 'Standalone,
      test_deps = [base],
      cmds = [
        ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (gnutls-available-p))' 2>&1 | grep -q t"],
      ],
    } | Test,

    tree_sitter = {
      class = 'Standalone,
      test_deps = [base],
      cmds = [
        ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (treesit-available-p))' 2>&1 | grep -q t"],
      ],
    } | Test,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "emacs",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
