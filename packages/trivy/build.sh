#!/bin/sh
set -ex

export GOROOT=/usr/go
# jsonv2 is REQUIRED, not optional: pkg/x/json unconditionally imports encoding/json/v2
# and encoding/json/jsontext, which only exist under this experiment.
export GOEXPERIMENT=jsonv2
export CGO_LDFLAGS="-fuse-ld=bfd"

# go 1.27 API bridge: encoding/json/v2 dropped the SkipFunc sentinel between 1.26 and 1.27 —
# the skip contract is now "return errors.ErrUnsupported with the decoder untouched" (see
# arshal_funcs.go lookup(): a maySkip arshaler returning ErrUnsupported falls through to the
# next/default handler, SkipFunc's exact old semantics). trivy 0.74.0 predates the rename.
# DROP THIS PATCH on the next trivy bump if upstream has adapted (the grep fails loudly if
# the call site is gone).
grep -q 'return json.SkipFunc' pkg/x/json/json.go
sed -i 's/return json.SkipFunc/return errors.ErrUnsupported/' pkg/x/json/json.go
grep -q '"errors"' pkg/x/json/json.go || sed -i 's/^import (/import (\n\t"errors"/' pkg/x/json/json.go

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/aquasecurity/trivy/pkg/version/app.ver=${MINIMAL_ARG_VERSION}'" -o trivy ./cmd/trivy

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 trivy $OUTPUT_DIR/usr/bin/trivy
