#!/bin/bash
set -euo pipefail

# Use the resolved target arch from build.ncl (MINIMAL_ARG_ARCH) rather than the
# build host's `uname -m`, so the correct installer is referenced on cross-builds.
installer="edgedelta-linux-${MINIMAL_ARG_ARCH}.sh"

# The installer is a Makeself self-extracting archive that, when run, would
# create a system user, install a service and start the agent. We don't want
# any of that — we only want the bundled binary. So extract the embedded
# gzip-compressed tar payload directly instead of executing the installer.
#
# Makeself appends the payload after a fixed number of header lines; the line
# count is embedded in the script itself (`offset=`head -n N "$0"`...`). Parse
# it out rather than hardcoding, so this keeps working across versions.
header_lines=$(grep -aoE 'head -n [0-9]+ "\$0"' "$installer" | head -1 | grep -oE 'head -n [0-9]+' | grep -oE '[0-9]+')
if [ -z "$header_lines" ]; then
  echo "could not determine Makeself payload offset in $installer" >&2
  exit 1
fi

byte_offset=$(head -n "$header_lines" "$installer" | wc -c | tr -d ' ')

mkdir -p payload
tail -c "+$((byte_offset + 1))" "$installer" | gzip -dc | tar -xof - -C payload

if [ ! -f payload/edgedelta ]; then
  echo "edgedelta binary not found in extracted payload" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 0755 payload/edgedelta "$OUTPUT_DIR/usr/bin/edgedelta"
