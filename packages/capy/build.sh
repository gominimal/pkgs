#!/bin/sh
set -ex

npm install -g --prefix=$OUTPUT_DIR/usr @capysc/cli@$MINIMAL_ARG_VERSION
