#!/bin/sh
set -ex


export GOROOT=/usr/go
go build -trimpath -o 'age' -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age
install -D -m 0755 age "$OUTPUT_DIR/usr/bin/age"

go build -trimpath -o 'age-keygen' -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age-keygen
install -D -m 0755 age-keygen "$OUTPUT_DIR/usr/bin/age-keygen"

# Upstream ships every cmd/ binary (age 1.3 added these two).
for cmd in age-inspect age-plugin-batchpass; do
  go build -trimpath -o "$cmd" -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" "./cmd/$cmd"
  install -D -m 0755 "$cmd" "$OUTPUT_DIR/usr/bin/$cmd"
done
