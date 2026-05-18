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
