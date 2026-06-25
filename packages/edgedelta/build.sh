#!/bin/bash
set -euo pipefail

ARCH="${MINIMAL_ARG_TARGET_ARCH}"

installer="edgedelta-linux-${ARCH}.sh"

# The installer is a Makeself self-extracting archive that, when run, would
# create a system user, install a service and start the agent. We don't want
# any of that — we only want the bundled binary. Safely extract the archive
# contents using the installer's native command-line options without executing
# the embedded installation script.
sh "$installer" --target payload --noexec

if [ ! -f payload/edgedelta ]; then
  echo "edgedelta binary not found in extracted payload" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 0755 payload/edgedelta "$OUTPUT_DIR/usr/bin/edgedelta"
