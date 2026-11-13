#!/bin/sh
set -ex

export GOROOT=/usr/go

# Inject version via the ldflag path crane's own .goreleaser.yml uses,
# so `crane version` reports the tag we built from rather than the
# Go-module fallback ("(devel)" for archive-tarball builds).
go build -trimpath \
  -ldflags "-buildid= -w -s -X 'github.com/google/go-containerregistry/cmd/crane/cmd.Version=${MINIMAL_ARG_VERSION}'" \
  -o crane ./cmd/crane

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 crane $OUTPUT_DIR/usr/bin/crane

# gcrane (crane plus GCR-specific commands) is in the same module and vendor
# tree. krane is not built: cmd/krane is a separate module whose k8s deps are
# not vendored here.
go build -trimpath \
  -ldflags "-buildid= -w -s -X 'github.com/google/go-containerregistry/cmd/crane/cmd.Version=${MINIMAL_ARG_VERSION}'" \
  -o gcrane ./cmd/gcrane
install -m 755 gcrane $OUTPUT_DIR/usr/bin/gcrane
