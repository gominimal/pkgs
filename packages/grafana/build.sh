#!/bin/sh
set -ex

mkdir -p $OUTPUT_DIR/usr/bin
mkdir -p $OUTPUT_DIR/usr/share/grafana

# Grafana 13 ships ONE binary. `grafana-server` and `grafana-cli` were removed
# upstream — through 12.x they were two shims of 2,557,169 bytes each (identical
# size, i.e. the same forwarder built twice) sitting next to the real ~500MB
# `grafana`, long deprecated in favour of the `grafana server` / `grafana cli`
# subcommands. Installing them unconditionally is what broke 12.4.3 -> 13.1.2:
#   install: cannot stat 'bin/grafana-server': No such file or directory
# Nothing else in pkgs referenced either name, so they are dropped rather than
# re-created as local shims.
install -m 755 bin/grafana $OUTPUT_DIR/usr/bin/grafana

cp -r public $OUTPUT_DIR/usr/share/grafana/
cp -r conf $OUTPUT_DIR/usr/share/grafana/
