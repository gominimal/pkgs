#!/bin/sh
set -ex

npm install -g --prefix=$OUTPUT_DIR/usr wrangler@$MINIMAL_ARG_VERSION
