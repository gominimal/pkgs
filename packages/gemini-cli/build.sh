#!/bin/bash
set -euo pipefail

npm install -g --prefix="$OUTPUT_DIR/usr" "@google/gemini-cli@$MINIMAL_ARG_VERSION"

