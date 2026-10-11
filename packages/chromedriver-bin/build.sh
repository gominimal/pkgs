#!/bin/bash
set -euo pipefail
# One Chrome for Testing chromedriver zip per arch arrives in the cwd.
if [ "$(uname -m)" = "x86_64" ]; then
  unzip -q chromedriver-linux64.zip
  DIR=chromedriver-linux64
else
  unzip -q chromedriver-linux-arm64.zip
  DIR=chromedriver-linux-arm64
fi
[ -x "$DIR/chromedriver" ] || { echo "expected $DIR/chromedriver in the CfT zip" >&2; exit 1; }
install -Dm755 "$DIR/chromedriver" "$OUTPUT_DIR/usr/bin/chromedriver"
install -Dm644 "$DIR/LICENSE.chromedriver" "$OUTPUT_DIR/usr/share/licenses/chromedriver/LICENSE"
install -Dm644 "$DIR/THIRD_PARTY_NOTICES.chromedriver" "$OUTPUT_DIR/usr/share/licenses/chromedriver/THIRD_PARTY_NOTICES"
