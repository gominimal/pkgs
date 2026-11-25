#!/bin/sh
# os-release(5): lets tools that identify the distro work in a Minimal box. The
# Rex installer, for one, refuses to run without it.
#
# Layout per the spec: the vendor file is /usr/lib/os-release, and
# /etc/os-release is a relative symlink to it, so a tool reading either path
# finds it.
#
# ID=minimal with no ID_LIKE, on purpose: claiming a parent distro (debian, say)
# would make tools reach for its package manager.
set -e

mkdir -p "$OUTPUT_DIR/usr/lib" "$OUTPUT_DIR/etc"
cat > "$OUTPUT_DIR/usr/lib/os-release" << "EOF"
NAME="Minimal"
ID=minimal
PRETTY_NAME="Minimal"
HOME_URL="https://minimal.dev"
EOF
ln -s ../usr/lib/os-release "$OUTPUT_DIR/etc/os-release"
