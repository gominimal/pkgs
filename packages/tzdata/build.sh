#!/bin/sh
set -e

ZONEINFO="$OUTPUT_DIR/usr/share/zoneinfo"
mkdir -p "$ZONEINFO"

# The zone sources upstream's Makefile compiles by default (PRIMARY_YDATA + etcetera + backward).
zic -b slim -d "$ZONEINFO" \
  africa antarctica asia australasia europe northamerica southamerica etcetera backward

# The tables that tzselect and Python's zoneinfo read alongside the compiled zones.
cp iso3166.tab zone.tab zone1970.tab "$ZONEINFO/"
