#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

mkdir -p $OUTPUT_DIR/usr/bin
go build -trimpath -ldflags "-buildid= -w -s -X 'main.version=${MINIMAL_ARG_VERSION}'" -o $OUTPUT_DIR/usr/bin/nats ./nats
