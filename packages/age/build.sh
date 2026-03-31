#!/bin/sh
set -ex


export GOROOT=/usr/go
go build -trimpath -o 'age' -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age
install -D -m 0755 age "$OUTPUT_DIR/usr/bin/age"

go build -trimpath -o 'age-keygen' -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age-keygen
install -D -m 0755 age-keygen "$OUTPUT_DIR/usr/bin/age-keygen"
