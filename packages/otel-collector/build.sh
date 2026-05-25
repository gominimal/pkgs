#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs stages the goproxy
# mirror at /goproxy/ under MINIMAL_INTERNAL_CS_BUILD=1.
# Outside CS this dir doesn't exist; build falls back to default GOPROXY.
if [ -d /goproxy ]; then
    export GOPROXY="file:///goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

# Install the OpenTelemetry Collector Builder (ocb)
go install -trimpath go.opentelemetry.io/collector/cmd/builder@v0.150.0
OCB=$(go env GOPATH)/bin/builder

# Build the collector using the upstream contrib manifest
$OCB --config=distributions/otelcol-contrib/manifest.yaml

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 _build/otelcol-contrib $OUTPUT_DIR/usr/bin/otelcol-contrib
