#!/bin/sh
set -ex

export GOROOT=/usr/go

LDFLAGS="-buildid= -w -s -X 'github.com/pulumi/pulumi/sdk/v3/go/common/version.Version=${MINIMAL_ARG_VERSION}'"

go build -C pkg -trimpath -ldflags "$LDFLAGS" -o ../pulumi github.com/pulumi/pulumi/pkg/v3/cmd/pulumi
go build -C sdk/go/pulumi-language-go -trimpath -ldflags "$LDFLAGS" -o pulumi-language-go .
go build -C sdk/nodejs/cmd/pulumi-language-nodejs -trimpath -ldflags "$LDFLAGS" -o pulumi-language-nodejs .
go build -C sdk/python/cmd/pulumi-language-python -trimpath -ldflags "$LDFLAGS" -o pulumi-language-python .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 pulumi $OUTPUT_DIR/usr/bin/pulumi
install -m 755 sdk/go/pulumi-language-go/pulumi-language-go $OUTPUT_DIR/usr/bin/pulumi-language-go
install -m 755 sdk/nodejs/cmd/pulumi-language-nodejs/pulumi-language-nodejs $OUTPUT_DIR/usr/bin/pulumi-language-nodejs
install -m 755 sdk/python/cmd/pulumi-language-python/pulumi-language-python $OUTPUT_DIR/usr/bin/pulumi-language-python
