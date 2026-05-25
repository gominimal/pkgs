#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs stages the goproxy
# mirror at /state/cs-mirror/goproxy/ under MINIMAL_INTERNAL_CS_BUILD=1.
# Outside CS this dir doesn't exist; build falls back to default GOPROXY.
if [ -d /state/cs-mirror/goproxy ]; then
    export GOPROXY="file:///state/cs-mirror/goproxy"
    export GOSUMDB=off
fi

export FZF_VERSION=$MINIMAL_ARG_VERSION
export FZF_REVISION=tarball

export GOROOT=/usr/go

go build -trimpath -ldflags "-buildid= -s -w -X main.version=${FZF_VERSION} -X main.revision=${FZF_REVISION}" -o bin/fzf

install -D -m 0755 bin/fzf "$OUTPUT_DIR/usr/bin/fzf"

install -D -m 0755 shell/completion.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/fzf"
