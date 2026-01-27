#!/bin/sh
set -ex

export GOROOT=/usr/go
export GOEXPERIMENT=jsonv2

go build -ldflags "-w -s -X 'github.com/aquasecurity/trivy/pkg/version/app.ver=${MINIMAL_ARG_VERSION}'" -o trivy ./cmd/trivy

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 trivy $OUTPUT_DIR/usr/bin/trivy
