#!/bin/bash
set -euo pipefail

# Meta-package: the payload is the runtime_deps roster.
mkdir -p "$OUTPUT_DIR/usr/share/doc/dev-language-servers"
cat > "$OUTPUT_DIR/usr/share/doc/dev-language-servers/README" << 'EOF'
Meta-package carrying a language-server roster as runtime dependencies:
gopls, rust (rust-analyzer), pyright + ruff, typescript-language-server
+ eslint, bash-language-server, clangd, nickel-lsp (nls), jdtls,
ruby-lsp, lua-language-server, zls (+ zig), haskell-language-server
(+ ghc).
EOF
