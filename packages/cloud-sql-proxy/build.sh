#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs hydrates the goproxy
# mirror at /goproxy. Outside CS this dir doesn't exist; the build
# falls back to the default GOPROXY.
if [ -d /goproxy ]; then
    export GOPROXY="file:///goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/GoogleCloudPlatform/cloud-sql-proxy/v2/cmd.versionString=${MINIMAL_ARG_VERSION}'" -o cloud-sql-proxy .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 cloud-sql-proxy $OUTPUT_DIR/usr/bin/cloud-sql-proxy
