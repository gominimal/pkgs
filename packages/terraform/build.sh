#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags "-w -s -X 'github.com/hashicorp/terraform/version.dev=no'" -o terraform .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 terraform $OUTPUT_DIR/usr/bin/terraform
