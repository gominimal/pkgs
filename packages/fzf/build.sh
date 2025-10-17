#!/bin/sh
set -ex

export FZF_VERSION=$MINIMAL_ARG_VERSION
export FZF_REVISION=tarball

export GOROOT=/usr/go

make
make install
install -D -m 0755 bin/fzf "$OUTPUT_DIR/usr/bin/fzf"

install -D -m 0755 shell/completion.bash "$OUTPUT_DIR/usr/share/bash-completion/completions/fzf"
