let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
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
let version = "31.1" in
{
  name = "emacs",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "fixrand.c" } | Local,
    # Backport of Emacs master b0143530 (bug#79687): tree-sitter >= 0.26
    # rejects the bare #match/#equal predicate names Emacs 30.2 emits.
    {
      url = "https://ftpmirror.gnu.org/emacs/emacs-%{version}.tar.xz",
      sha256 = "1da5790d9580c81932b5bf700633114468da7b3412d69faa767daebf974f4586",
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
    bash,
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
    ebrowse = { glob = "usr/bin/ebrowse" } | OutputBin,
    # `ctags` was REMOVED in Emacs 31.1 — etc/NEWS: "Emacs's old 'ctags'
    # program is no longer built or installed. You are encouraged to use
    # Universal Ctags instead." `etags` below is unaffected and still ships;
    # `etags --ctags` reproduces the old behaviour if anything needs it.
    "emacs-31.1" = { glob = "usr/bin/emacs-31.1" } | OutputBin,
    emacs = { glob = "usr/bin/emacs" } | OutputBin,
    etags = { glob = "usr/bin/etags" } | OutputBin,
    emacsclient = { glob = "usr/bin/emacsclient" } | OutputBin,
    libexec = { glob = "usr/libexec/emacs/**", allow_executable = true } | OutputData,
    share = { glob = "usr/share/emacs/**", allow_executable = true } | OutputData,
  },

  tests = {
    version = standaloneTest "/usr/bin/emacs --version",

    batch_eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"hello\")' 2>&1 | grep -q hello"],
        ],
      } | Test,

    byte_compile =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '(defun test-fn () 42)' > /tmp/test.el && emacs --batch -f batch-byte-compile /tmp/test.el && test -f /tmp/test.elc"],
        ],
      } | Test,

    gnutls =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (gnutls-available-p))' 2>&1 | grep -q t"],
        ],
      } | Test,

    # ── configure-flag coverage ────────────────────────────────────────
    # build.sh configures --with-xml2 --with-zlib --with-modules
    # --with-threads --with-file-notification=inotify. Each of those was
    # previously unasserted: if a dependency shift left one out at configure
    # time the build would still SUCCEED and no signal would fire. These are
    # the cheapest possible guards — one predicate each.
    libxml2_available =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (libxml-available-p))' 2>&1 | grep -q t"],
        ],
      } | Test,

    zlib_available =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (zlib-available-p))' 2>&1 | grep -q t"],
        ],
      } | Test,

    dynamic_modules =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" module-file-suffix)' 2>&1 | grep -q '[.]so'"],
        ],
      } | Test,

    threads =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (and (fboundp (quote make-thread)) t))' 2>&1 | grep -q t"],
        ],
      } | Test,

    inotify_file_notify =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (and (featurep (quote inotify)) t))' 2>&1 | grep -q t"],
        ],
      } | Test,

    # emacsclient is a declared OutputBin that nothing exercised.
    emacsclient_runs =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacsclient --version 2>&1 | grep -qi emacsclient"],
        ],
      } | Test,

    tree_sitter =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "emacs --batch --eval '(message \"%s\" (treesit-available-p))' 2>&1 | grep -q t"],
        ],
      } | Test,

    # Guards the ?-suffix predicate serialisation that libtree-sitter >= 0.26
    # requires, for both the legacy keywords and the new aliases. This used to
    # guard our treesit-predicates-0.26.patch; 31.1 carries the fix upstream
    # (master b0143530), so the test now guards UPSTREAM's behaviour. Keep it:
    # it is the regression signal regardless of who supplies the fix.
    treesit_predicate_syntax =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "out=$(emacs --batch --eval '(princ (treesit-query-expand (quote ((a) @x (:match \"^a\" @x) (:equal @x \"a\") (:match? @x \"^a\") (:eq? @x \"a\")))))' 2>/dev/null); echo \"$out\"; echo \"$out\" | grep -q '(#match? \"^a\" @x) (#eq? @x \"a\") (#match? @x \"^a\") (#eq? @x \"a\")'"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "emacs",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
