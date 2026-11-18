#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*
# No cgo: the binary must run on the res-server host (Ubuntu), outside any
# minimal sandbox, with nothing of ours beside it. Only the TPM simulator and
# the key manager in this repository use cgo, and gotpm links neither.
export CGO_ENABLED=0

# The command is its own module (cmd/go.mod); the repository's go.work ties
# it to the modules beside it.
cd go-tpm-tools-$MINIMAL_ARG_VERSION/cmd

go build -trimpath -ldflags="-s -w -buildid=" -o $OUTPUT_DIR/usr/bin/gotpm ./gotpm
