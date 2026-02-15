#!/bin/sh
set -ex

export GOROOT=/usr/go

go mod tidy
CGO_ENABLED=0 go build -ldflags "-w -s" -o minimal-sshd .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 minimal-sshd $OUTPUT_DIR/usr/bin/minimal-sshd
