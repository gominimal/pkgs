#!/bin/sh
# Header-only: install the two header directories cvc5 consumes, exactly as
# cvc5's own FindSymFPU.cmake ExternalProject would (core/ + utils/), minus
# the in-tree Makefiles.
set -eu
for d in core utils; do
  mkdir -p "$OUTPUT_DIR/usr/include/symfpu/$d"
  cp "$d"/*.h "$OUTPUT_DIR/usr/include/symfpu/$d/"
done
