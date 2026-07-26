#!/bin/sh
set -ex

# Install from the sha256-pinned registry tarball fetched as a Source (not from
# the live `cf@<version>` tag), so the exact audited artifact is what ships.
npm install -g --prefix=$OUTPUT_DIR/usr "cf-${MINIMAL_ARG_VERSION}.tgz"
