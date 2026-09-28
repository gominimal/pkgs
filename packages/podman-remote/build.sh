#!/bin/sh
set -eux

export GOROOT=/usr/go

# The REMOTE client only. `podman` proper is a container engine that wants
# conmon, crun/runc, netavark, slirp4netns and a rootless storage stack; the
# agentbox image does not run containers locally, it talks to a podman service
# over a socket. The `remote` build tag is upstream's own switch for that:
# it compiles cmd/podman without the libpod engine, which is also why this
# builds with no cgo and no C dependencies at all.
#
# Building at the repo root is what the generic Go template did and it fails
# with "no Go files in /build" — podman's entrypoint is ./cmd/podman.
CGO_ENABLED=0 go build \
  -trimpath \
  -tags "remote exclude_graphdriver_btrfs exclude_graphdriver_devicemapper containers_image_openpgp" \
  -ldflags "-buildid= -w -s -X github.com/containers/podman/v6/libpod/define.gitCommit= -X github.com/containers/podman/v6/libpod/define.buildInfo=" \
  -o podman-remote ./cmd/podman

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 podman-remote "$OUTPUT_DIR/usr/bin/podman-remote"
