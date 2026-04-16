#!/bin/sh
set -ex

mkdir -p $OUTPUT_DIR/usr/bin
mkdir -p $OUTPUT_DIR/usr/share/grafana

install -m 755 bin/grafana $OUTPUT_DIR/usr/bin/grafana
install -m 755 bin/grafana-server $OUTPUT_DIR/usr/bin/grafana-server
install -m 755 bin/grafana-cli $OUTPUT_DIR/usr/bin/grafana-cli

cp -r public $OUTPUT_DIR/usr/share/grafana/
cp -r conf $OUTPUT_DIR/usr/share/grafana/
