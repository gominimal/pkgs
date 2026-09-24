#!/bin/sh
set -ex

# Go 1.27 json/v2 fix (upstream trivy dc3c56eed5), applied by name and proven
# to have landed. Drop at the next trivy release.
patch -Np1 -i go127-json-skipfunc.patch
grep -q "errors.ErrUnsupported" pkg/x/json/json.go || {
  echo "ERROR: go127-json-skipfunc patch did not land in pkg/x/json/json.go" >&2
  exit 1
}

export GOROOT=/usr/go
export GOEXPERIMENT=jsonv2
export CGO_LDFLAGS="-fuse-ld=bfd"

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/aquasecurity/trivy/pkg/version/app.ver=${MINIMAL_ARG_VERSION}'" -o trivy ./cmd/trivy

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 trivy $OUTPUT_DIR/usr/bin/trivy
