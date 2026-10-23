#!/bin/bash
set -euo pipefail
export GOROOT=/usr/go CGO_ENABLED=0
go build -trimpath -ldflags "-buildid= -s -w -X main.bashPath=/bin/bash" -o direnv .
install -Dm755 direnv "$OUTPUT_DIR/usr/bin/direnv"
