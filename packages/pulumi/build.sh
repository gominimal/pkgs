#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -C pkg -ldflags "-w -s -X 'github.com/pulumi/pulumi/sdk/v3/go/common/version.Version=${MINIMAL_ARG_VERSION}'" -o ../pulumi github.com/pulumi/pulumi/pkg/v3/cmd/pulumi

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 pulumi $OUTPUT_DIR/usr/bin/pulumi
