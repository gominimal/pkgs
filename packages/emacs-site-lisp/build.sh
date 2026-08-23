#!/bin/sh
set -ex

SITE_LISP="$OUTPUT_DIR/usr/share/emacs/site-lisp"
mkdir -p "$SITE_LISP"

# Install each elisp package into its own directory under site-lisp.
# The emacs package's site-start.el adds every site-lisp subdirectory
# (and its lisp/ and extensions/ children) to load-path.
install_pkg() {
  name="$1"
  src_dir="$2"
  dest="$SITE_LISP/$name"
  mkdir -p "$dest"
  cp "$src_dir"/*.el "$dest/" 2>/dev/null || true
  for subdir in lisp extensions; do
    if [ -d "$src_dir/$subdir" ]; then
      mkdir -p "$dest/$subdir"
      cp "$src_dir/$subdir/"*.el "$dest/$subdir/" 2>/dev/null || true
    fi
  done
}

# Completion framework
install_pkg vertico vertico-2.12
install_pkg orderless orderless-1.7
install_pkg marginalia marginalia-2.11
install_pkg consult consult-3.7
install_pkg corfu corfu-2.13
install_pkg cape cape-2.8
install_pkg embark embark-1.2
# avy is not packaged here; drop the one embark file that needs it.
rm -f "$SITE_LISP/embark/avy-embark-collect.el"

# Corfu terminal rendering (codeberg archives extract to the repo name)
install_pkg popon emacs-popon
install_pkg corfu-terminal emacs-corfu-terminal
# corfu-terminal.el's `cl-defmethod ... &context (corfu-terminal-mode ...)'
# forms come before the define-minor-mode that declares the variable.
# cl-generic byte-compiles the &context dispatcher at *load* time, so every
# load of the .elc prints "reference to free variable 'corfu-terminal-mode'"
# in *Messages*. Define the variable ahead of the first method. It must be
# a defvar WITH a value: a bare (defvar sym) only affects the compilation
# unit it appears in, whereas (defvar sym nil) marks the symbol special
# globally when it executes, which is what the runtime dispatcher compile
# checks. nil is the same initial value define-minor-mode sets, so the
# later definition is unaffected. (Upstream is archived, so the patch is
# carried here rather than sent upstream.)
sed -i '/^(cl-defmethod corfu--popup-support-p/i (defvar corfu-terminal-mode nil) ; defined early for the \&context dispatchers below (minimal patch)' \
  "$SITE_LISP/corfu-terminal/corfu-terminal.el"
grep -q '^(defvar corfu-terminal-mode nil)' "$SITE_LISP/corfu-terminal/corfu-terminal.el"

# Editable grep buffers
install_pkg wgrep Emacs-wgrep-3.0.0

# Magit dependencies (must be installed before magit)
install_pkg compat compat-31.0.0.2
install_pkg llama llama-1.0.5
install_pkg cond-let cond-let-1.1.3
install_pkg transient transient-0.13.7/lisp
install_pkg with-editor with-editor-3.5.3/lisp

# Magit itself (lisp/ also carries magit-section, git-commit, git-rebase)
install_pkg magit magit-4.7.0/lisp

# Language modes without a built-in ts-mode
install_pkg markdown-mode markdown-mode-2.8
install_pkg nickel-mode nickel-mode-e2dcd6cf66d9b5bcde3e3cd69efe053f73b081ab
# zig-mode requires reformatter at load time; drop its ert test file.
install_pkg reformatter emacs-reformatter-0.7
rm -f "$SITE_LISP/reformatter/reformatter-tests.el"
install_pkg zig-mode zig-mode-66490933a468b5d55a90645c4c87067c508ccd04
install_pkg haskell-ts-mode haskell-ts-mode

# Extra flymake backends
install_pkg flymake-ruff flymake-ruff-ef4a6caed72bce77a27bda54ffb30e3fdb0e7d76
install_pkg flymake-eslint flymake-eslint-1.5.0

# Build load-path arguments for byte-compilation
LOAD_PATH=""
for dir in "$SITE_LISP"/*/; do
  LOAD_PATH="$LOAD_PATH -L $dir"
  for subdir in lisp extensions; do
    if [ -d "${dir}${subdir}" ]; then
      LOAD_PATH="$LOAD_PATH -L ${dir}${subdir}"
    fi
  done
done

# Byte-compile all .el files
for dir in "$SITE_LISP"/*/; do
  for el in "$dir"*.el "$dir"lisp/*.el "$dir"extensions/*.el; do
    [ -f "$el" ] || continue
    emacs --batch $LOAD_PATH -f batch-byte-compile "$el" 2>&1 || true
  done
done

# Ensure .elc files are newer than .el files.  Reproducible-build
# settings (SOURCE_DATE_EPOCH=0) can cause byte-compiled files to
# carry an epoch-0 timestamp, making Emacs think they are stale.
find "$SITE_LISP" -name '*.elc' -exec touch {} +

# ── Tree-sitter grammars ─────────────────────────────────────────────
TS_DIR="$OUTPUT_DIR/usr/lib/emacs/tree-sitter"
mkdir -p "$TS_DIR"

CFLAGS="-O2 -fPIC"

build_grammar() {
  name="$1"
  src_dir="$2"
  scanner="$3"
  files="$src_dir/src/parser.c"
  if [ -n "$scanner" ] && [ -f "$src_dir/src/$scanner" ]; then
    files="$files $src_dir/src/$scanner"
  fi
  gcc $CFLAGS -shared -o "$TS_DIR/libtree-sitter-${name}.so" \
    -I "$src_dir/src" $files
}

build_grammar rust       tree-sitter-rust-0.23.2         scanner.c
build_grammar go         tree-sitter-go-0.23.4           ""
build_grammar python     tree-sitter-python-0.23.6       scanner.c
build_grammar bash       tree-sitter-bash-0.23.3         scanner.c
build_grammar c          tree-sitter-c-0.23.4            ""
build_grammar cpp        tree-sitter-cpp-0.23.4          scanner.c
build_grammar json       tree-sitter-json-0.24.8         ""
build_grammar yaml       tree-sitter-yaml-0.7.2          scanner.c
build_grammar toml       tree-sitter-toml-0.7.0          scanner.c
build_grammar gomod      tree-sitter-go-mod-1.1.0        ""
build_grammar java       tree-sitter-java-0.23.5         ""
build_grammar ruby       tree-sitter-ruby-0.23.1         scanner.c
build_grammar lua        tree-sitter-lua-0.5.0           scanner.c
build_grammar zig        tree-sitter-zig-1.1.2           ""
build_grammar haskell    tree-sitter-haskell-0.23.1      scanner.c
build_grammar dockerfile tree-sitter-dockerfile-0.2.0    scanner.c

# TypeScript repo has typescript and tsx in separate directories
gcc $CFLAGS -shared -o "$TS_DIR/libtree-sitter-typescript.so" \
  -I tree-sitter-typescript-0.23.2/typescript/src \
  tree-sitter-typescript-0.23.2/typescript/src/parser.c \
  tree-sitter-typescript-0.23.2/typescript/src/scanner.c

gcc $CFLAGS -shared -o "$TS_DIR/libtree-sitter-tsx.so" \
  -I tree-sitter-typescript-0.23.2/tsx/src \
  tree-sitter-typescript-0.23.2/tsx/src/parser.c \
  tree-sitter-typescript-0.23.2/tsx/src/scanner.c
