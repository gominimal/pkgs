#!/bin/sh
# Unpack the pinned registry tarball into a package-private prefix laid out like
# `npm install -g --prefix` (lib/node_modules/<name>), without running npm at all:
# leaflet has no dependencies and no install scripts.
set -eu
dest="$OUTPUT_DIR/usr/libexec/leaflet/lib/node_modules/leaflet"
mkdir -p "$dest"
tar -xzf "leaflet-$MINIMAL_ARG_VERSION.tgz" -C "$dest" --strip-components=1
test -f "$dest/dist/leaflet.js"
test -f "$dest/dist/leaflet.css"
# Two upstream sources (src/geo/crs/CRS.Earth.js, src/layer/tile/GridLayer.js)
# carry +x in the tarball; this is a data output, so clear it on files only.
find "$dest" -type f -exec chmod a-x {} +
test -z "$(find "$dest" -type f -perm /111)"
