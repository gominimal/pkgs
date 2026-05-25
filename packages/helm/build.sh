#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs stages the goproxy
# mirror at /state/cs-mirror/goproxy/ under MINIMAL_INTERNAL_CS_BUILD=1.
# Outside CS this dir doesn't exist; build falls back to default GOPROXY.
if [ -d /state/cs-mirror/goproxy ]; then
    export GOPROXY="file:///state/cs-mirror/goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*
export CGO_ENABLED=0

go build -trimpath -ldflags "-buildid= -w -s -X helm.sh/helm/v4/internal/version.version=v${MINIMAL_ARG_VERSION}" -o helm ./cmd/helm

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 helm $OUTPUT_DIR/usr/bin/helm
