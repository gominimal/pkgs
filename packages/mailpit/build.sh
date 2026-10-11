#!/bin/bash
set -euo pipefail
export GOROOT=/usr/go CGO_ENABLED=0
export HOME="$PWD/.home" npm_config_cache="$PWD/.npm"
npm ci --no-audit --no-fund
npm run package
go build -trimpath -ldflags "-buildid= -s -w -X github.com/axllent/mailpit/config.Version=v$MINIMAL_ARG_VERSION" -o mailpit .
install -Dm755 mailpit "$OUTPUT_DIR/usr/bin/mailpit"
