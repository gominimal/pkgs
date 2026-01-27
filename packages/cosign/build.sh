#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags "-w -s -X 'sigs.k8s.io/release-utils/version.gitVersion=v${MINIMAL_ARG_VERSION}'" -o cosign ./cmd/cosign

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 cosign $OUTPUT_DIR/usr/bin/cosign
