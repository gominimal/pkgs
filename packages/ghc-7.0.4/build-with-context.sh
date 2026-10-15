#!/bin/bash
# x86_64 entry point: build.sh, and when the build fails, the lines of the make log just before make's
# first "] Error", each cut to 160 columns (link lines run to kilobytes; failure output is truncated to ~4 KiB)
./build.sh && exit 0
rc=$?
L=$(find /build -maxdepth 3 -name all.log -type f 2>/dev/null | head -1)
if [ -n "$L" ]; then
  N=$(grep -an -m1 '\] Error ' "$L" | cut -d: -f1)
  echo "--- $L before line ${N:-?} ---" >&2
  [ -n "$N" ] && head -n "$N" "$L" | tail -22 | cut -c1-160 >&2
fi
exit $rc
