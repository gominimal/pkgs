#!/bin/bash
set -euo pipefail

# Reproducibility flags (see AGENTS.md).
CFLAGS="${CFLAGS:-} -O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"

# Same shape as neovim's bundled-parser recipe (MarkdownParserCMakeLists.txt):
# the repo contains two grammars, both loadable from nvim's runtime 'parser/'
# directory.
mkdir -p "$OUTPUT_DIR/usr/lib/nvim/parser"
gcc $CFLAGS -std=c11 -fPIC -I tree-sitter-markdown/src -shared \
  tree-sitter-markdown/src/*.c \
  -Wl,--build-id=none -o "$OUTPUT_DIR/usr/lib/nvim/parser/markdown.so"
gcc $CFLAGS -std=c11 -fPIC -I tree-sitter-markdown-inline/src -shared \
  tree-sitter-markdown-inline/src/*.c \
  -Wl,--build-id=none -o "$OUTPUT_DIR/usr/lib/nvim/parser/markdown_inline.so"
