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
# ALL call sites (buildbot arm found a second one in pkg/iac/.../parameter.go after the first
# patch covered only pkg/x/json): rewrite every json.SkipFunc in the tree and make sure each
# touched file imports "errors" (block form, or single-line if the file has no import block).
SKIP_FILES=$(grep -rl 'json\.SkipFunc' --include='*.go' . || true)
[ -n "$SKIP_FILES" ] || { echo "trivy: no json.SkipFunc call sites left — drop this bridge"; exit 1; }
for f in $SKIP_FILES; do
  sed -i 's/json\.SkipFunc/errors.ErrUnsupported/g' "$f"
  if ! grep -qE '^\s*"errors"$|^import "errors"$' "$f"; then
    if grep -q '^import (' "$f"; then sed -i '0,/^import (/s//import (\n\t"errors"/' "$f"
    else sed -i '0,/^package .*/s//&\n\nimport "errors"/' "$f"; fi
  fi
  echo "  jsonv2 bridge: $f"
done
grep -rq 'json\.SkipFunc' --include='*.go' . && { echo "trivy: json.SkipFunc survived the rewrite"; exit 1; }

go build -trimpath -ldflags "-buildid= -w -s -X 'github.com/aquasecurity/trivy/pkg/version/app.ver=${MINIMAL_ARG_VERSION}'" -o trivy ./cmd/trivy

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 trivy $OUTPUT_DIR/usr/bin/trivy
