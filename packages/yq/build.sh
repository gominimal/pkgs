#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/mikefarah/yq/v4/cmd.Version=${MINIMAL_ARG_VERSION}'" -o yq .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 yq $OUTPUT_DIR/usr/bin/yq
