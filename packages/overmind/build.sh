#!/bin/bash
set -euo pipefail
export GOROOT=/usr/go CGO_ENABLED=0
go build -trimpath -ldflags "-buildid= -s -w" -o overmind .
install -Dm755 overmind "$OUTPUT_DIR/usr/bin/overmind"
