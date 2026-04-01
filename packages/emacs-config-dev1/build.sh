#!/bin/sh
set -ex

SITE_LISP="$OUTPUT_DIR/usr/share/emacs/site-lisp"
mkdir -p "$SITE_LISP"

# Install each elisp package into its own directory under site-lisp
install_pkg() {
  local name="$1"
  local src_dir="$2"
  local dest="$SITE_LISP/$name"
  mkdir -p "$dest"
  cp "$src_dir"/*.el "$dest/" 2>/dev/null || true
  # Some packages keep .el files in subdirectories
  for subdir in lisp extensions; do
    if [ -d "$src_dir/$subdir" ]; then
      mkdir -p "$dest/$subdir"
      cp "$src_dir/$subdir/"*.el "$dest/$subdir/" 2>/dev/null || true
    fi
  done
}

# Completion framework
install_pkg vertico vertico-2.8
install_pkg orderless orderless-1.6
install_pkg marginalia marginalia-2.10
install_pkg consult consult-3.4
install_pkg corfu corfu-2.9

# Which-key
install_pkg which-key emacs-which-key-3.6.0

# Magit dependencies (must be installed before magit)
install_pkg compat compat-30.1.0.1
install_pkg dash dash.el-2.20.0
install_pkg transient transient-0.12.0/lisp
install_pkg with-editor with-editor-3.4.9/lisp

# Magit itself
install_pkg magit magit-4.5.0/lisp

# Extra modes
install_pkg markdown-mode markdown-mode-2.8
install_pkg yaml-mode yaml-mode-0.0.13
install_pkg dockerfile-mode dockerfile-mode-1.9
install_pkg nickel-mode nickel-mode-e2dcd6cf66d9b5bcde3e3cd69efe053f73b081ab
install_pkg rust-mode rust-mode-1.0.6

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

# Install init file as a composable config fragment
cp init.el "$SITE_LISP/minimal-init-dev1.el"
emacs --batch $LOAD_PATH -f batch-byte-compile "$SITE_LISP/minimal-init-dev1.el" 2>&1 || true

# Ensure .elc files are newer than .el files.  Reproducible-build
# settings (SOURCE_DATE_EPOCH=0) can cause byte-compiled files to
# carry an epoch-0 timestamp, making Emacs think they are stale.
find "$SITE_LISP" -name '*.elc' -exec touch {} +

# ── Tree-sitter grammars ─────────────────────────────────────────────
TS_DIR="$OUTPUT_DIR/usr/lib/emacs/tree-sitter"
mkdir -p "$TS_DIR"

CFLAGS="-O2 -fPIC"

build_grammar() {
  local name="$1"
  local src_dir="$2"
  local scanner="$3"
  local files="$src_dir/src/parser.c"
  if [ -n "$scanner" ] && [ -f "$src_dir/src/$scanner" ]; then
    files="$files $src_dir/src/$scanner"
  fi
  gcc $CFLAGS -shared -o "$TS_DIR/libtree-sitter-${name}.so" \
    -I "$src_dir/src" $files
}

build_grammar rust    tree-sitter-rust-0.23.2       scanner.c
build_grammar go      tree-sitter-go-0.23.4         ""
build_grammar python  tree-sitter-python-0.23.6     scanner.c
build_grammar bash    tree-sitter-bash-0.23.3        scanner.c
build_grammar c       tree-sitter-c-0.23.4          ""
build_grammar cpp     tree-sitter-cpp-0.23.4        scanner.c
build_grammar json    tree-sitter-json-0.24.8       ""
build_grammar yaml    tree-sitter-yaml-0.7.2        scanner.c
build_grammar toml    tree-sitter-toml-0.7.0        scanner.c
build_grammar gomod   tree-sitter-go-mod-1.1.0      ""

# TypeScript repo has typescript and tsx in separate directories
gcc $CFLAGS -shared -o "$TS_DIR/libtree-sitter-typescript.so" \
  -I tree-sitter-typescript-0.23.2/typescript/src \
  tree-sitter-typescript-0.23.2/typescript/src/parser.c \
  tree-sitter-typescript-0.23.2/typescript/src/scanner.c

gcc $CFLAGS -shared -o "$TS_DIR/libtree-sitter-tsx.so" \
  -I tree-sitter-typescript-0.23.2/tsx/src \
  tree-sitter-typescript-0.23.2/tsx/src/parser.c \
  tree-sitter-typescript-0.23.2/tsx/src/scanner.c
