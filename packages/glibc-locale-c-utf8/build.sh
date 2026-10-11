#!/bin/bash
set -euo pipefail
# Compile glibc's C.UTF-8 locale in directory (not archive) form. glibc's
# setlocale() looks in /usr/lib/locale/locale-archive first and then in
# /usr/lib/locale/<name>/, so this adds the locale without rewriting the
# archive that the glibc package owns.
mkdir -p "$OUTPUT_DIR/usr/lib/locale"
localedef --no-archive -i C -f UTF-8 "$OUTPUT_DIR/usr/lib/locale/C.utf8"
[ -f "$OUTPUT_DIR/usr/lib/locale/C.utf8/LC_CTYPE" ] || { echo "localedef produced no LC_CTYPE" >&2; exit 1; }
