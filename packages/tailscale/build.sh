#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -ldflags "-w -s -X 'tailscale.com/version.shortStamp=${MINIMAL_ARG_VERSION}' -X 'tailscale.com/version.longStamp=${MINIMAL_ARG_VERSION}'" -o tailscale ./cmd/tailscale
go build -ldflags "-w -s -X 'tailscale.com/version.shortStamp=${MINIMAL_ARG_VERSION}' -X 'tailscale.com/version.longStamp=${MINIMAL_ARG_VERSION}'" -o tailscaled ./cmd/tailscaled

mkdir -p $OUTPUT_DIR/usr/bin $OUTPUT_DIR/usr/sbin
install -m 755 tailscale $OUTPUT_DIR/usr/bin/tailscale
install -m 755 tailscaled $OUTPUT_DIR/usr/sbin/tailscaled
