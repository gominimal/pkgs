#!/bin/sh
set -ex

# Go 1.27 json/v2 fix (upstream trivy dc3c56eed5), applied by name and proven
# to have landed. Drop at the next trivy release.
patch -Np1 -i go127-json-skipfunc.patch
# Fail if ANY Go-1.26-only json/v2 usage survives anywhere in the tree, not
# just the lines this patch touches.
# One grep (no pipe): its exit status alone means "a match exists", which is
# portable across GNU/BSD greps (a `| grep -v` stage's status on empty input is not).
if grep -rn --include='*.go' --exclude='*_test.go' -e 'json\.SkipFunc' -e 'json:",inline"' .; then
  echo "ERROR: Go 1.26-only json/v2 usage remains (see above); extend go127-json-skipfunc.patch" >&2
  exit 1
fi

export GOROOT=/usr/go
export GOEXPERIMENT=jsonv2
export CGO_LDFLAGS="-fuse-ld=bfd"

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/aquasecurity/trivy/pkg/version/app.ver=${MINIMAL_ARG_VERSION}'" -o trivy ./cmd/trivy

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 trivy $OUTPUT_DIR/usr/bin/trivy
