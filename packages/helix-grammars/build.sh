#!/bin/bash
set -euo pipefail

# Helix dlopens grammars from <runtime>/grammars/<grammar-id>.so, and the helix
# package bakes HELIX_DEFAULT_RUNTIME=/usr/lib/helix/runtime into the binary, so
# that is where these land — merged with the queries helix installs alongside.
GRAMMAR_DIR="$OUTPUT_DIR/usr/lib/helix/runtime/grammars"
mkdir -p "$GRAMMAR_DIR"

# Reproducibility flags (see AGENTS.md). -O3 -fPIC -shared and the relro/now
# link flags mirror what helix-loader/src/grammar.rs passes for a native build.
CFLAGS="-O3 -fPIC -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
LDFLAGS="-Wl,--build-id=none -Wl,-z,relro,-z,now"

# Each Source extracts to <repo>-<40-char rev>/; resolve that without repeating
# the revisions here (they live in build.ncl alone). The length test keeps
# tree-sitter-go from matching tree-sitter-go-mod / tree-sitter-go-work.
src_dir() {
  local repo="$1" d
  for d in "$repo"-*/; do
    d="${d%/}"
    if [ -d "$d" ] && [ "${#d}" -eq "$((${#repo} + 41))" ]; then
      printf '%s' "$d"
      return 0
    fi
  done
  echo "no extracted source directory for $repo" >&2
  return 1
}

# build_grammar <grammar-id> <repo> [subpath]
#
# Mirrors build_tree_sitter_library() in helix-loader/src/grammar.rs: parser.c
# plus scanner.c, or scanner.cc when there is no .c scanner (helix checks in
# that order and uses at most one). C compiles at -std=c11, C++ scanners at
# -std=c++14 -fno-exceptions into an object that gets linked in — parser.c is
# always C, so g++ needs an explicit -x c for it.
build_grammar() {
  local id="$1" repo="$2" subpath="${3:-}"
  local dir src
  dir="$(src_dir "$repo")"
  src="$dir${subpath:+/$subpath}/src"

  if [ -f "$src/scanner.c" ]; then
    gcc $CFLAGS -shared -std=c11 -I "$src" \
      "$src/parser.c" "$src/scanner.c" $LDFLAGS -o "$GRAMMAR_DIR/$id.so"
  elif [ -f "$src/scanner.cc" ]; then
    g++ $CFLAGS -std=c++14 -fno-exceptions -I "$src" -c "$src/scanner.cc" -o scanner.o
    g++ $CFLAGS -shared -I "$src" \
      scanner.o -x c -std=c11 "$src/parser.c" $LDFLAGS -o "$GRAMMAR_DIR/$id.so"
    rm -f scanner.o
  else
    gcc $CFLAGS -shared -std=c11 -I "$src" \
      "$src/parser.c" $LDFLAGS -o "$GRAMMAR_DIR/$id.so"
  fi
}

# ── Languages with a stack under stacks/ ─────────────────────────────────
build_grammar bash             tree-sitter-bash
build_grammar c                tree-sitter-c
build_grammar cmake            tree-sitter-cmake
build_grammar cpp              tree-sitter-cpp
build_grammar go               tree-sitter-go
build_grammar gomod            tree-sitter-go-mod
build_grammar gowork           tree-sitter-go-work
build_grammar haskell          tree-sitter-haskell
build_grammar java             tree-sitter-java
build_grammar javascript       tree-sitter-javascript
build_grammar kotlin           tree-sitter-kotlin
build_grammar lean             tree-sitter-lean
build_grammar make             tree-sitter-make
build_grammar meson            tree-sitter-meson
build_grammar nickel           tree-sitter-nickel
build_grammar ocaml            tree-sitter-ocaml              ocaml
build_grammar ocaml-interface  tree-sitter-ocaml              interface
build_grammar odin             tree-sitter-odin
build_grammar python           tree-sitter-python
build_grammar rust             tree-sitter-rust
build_grammar tsx              tree-sitter-typescript         tsx
build_grammar typescript       tree-sitter-typescript         typescript
build_grammar zig              tree-sitter-zig

# ── Data, config and markup formats ──────────────────────────────────────
build_grammar css              tree-sitter-css
build_grammar dockerfile       tree-sitter-dockerfile
build_grammar hcl              tree-sitter-hcl
build_grammar html             tree-sitter-html
build_grammar ini              tree-sitter-ini
build_grammar json             tree-sitter-json
build_grammar json5            tree-sitter-json5
build_grammar markdown         tree-sitter-markdown           tree-sitter-markdown
build_grammar markdown_inline  tree-sitter-markdown           tree-sitter-markdown-inline
build_grammar proto            tree-sitter-proto
build_grammar scss             tree-sitter-scss
build_grammar sql              tree-sitter-sql
build_grammar toml             tree-sitter-toml
build_grammar xml              tree-sitter-xml
build_grammar yaml             tree-sitter-yaml

# ── Git working buffers ──────────────────────────────────────────────────
build_grammar diff             tree-sitter-diff
build_grammar git-config       tree-sitter-git-config
build_grammar git-rebase       tree-sitter-git-rebase
build_grammar gitattributes    tree-sitter-gitattributes
build_grammar gitcommit        tree-sitter-gitcommit
build_grammar gitignore        tree-sitter-gitignore

# ── Low-level, for the reveng stack ──────────────────────────────────────
build_grammar llvm             tree-sitter-llvm
build_grammar nasm             tree-sitter-nasm

# Every grammar must export tree_sitter_<id>, with hyphens as underscores — that
# is the symbol helix resolves after dlopen. A wrong subpath still compiles fine
# and yields a .so helix silently can't use, so assert it here instead.
for so in "$GRAMMAR_DIR"/*.so; do
  id="$(basename "$so" .so)"
  sym="tree_sitter_${id//-/_}"
  if ! nm -D --defined-only "$so" | grep -q " $sym\$"; then
    echo "$so does not export $sym" >&2
    exit 1
  fi
done
