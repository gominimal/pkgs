#!/bin/sh
set -ex

# The @capysc/cli source tarball is declared as a Source in build.ncl
# (extract = true, strip_prefix), so its contents are already unpacked into the
# working directory. Build it from source rather than installing the prebuilt
# npm artifact.

npm install                  # no committed lockfile upstream -> install, not ci
npm run build                # tsc -> dist/
npm pkg delete bin.capy-dev  # match the published artifact (upstream prepublishOnly)

# Stage the freshly built package + its runtime deps into the output prefix.
npm install -g --prefix="$OUTPUT_DIR/usr" .
