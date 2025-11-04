#!/bin/sh
set -ex

export GOROOT=/usr/go

export BUILDTAGS=containers_image_openpgp
export DISABLE_DOCS=1

make
DESTDIR=$OUTPUT_DIR PREFIX=/usr make install
