#!/bin/sh
set -eu

tar -xof "spotbugs-${MINIMAL_ARG_VERSION}.tgz"
SRC="spotbugs-${MINIMAL_ARG_VERSION}"
test -x "$SRC/bin/spotbugs"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/spotbugs"
cp -r "$SRC"/* "$OUTPUT_DIR/usr/share/spotbugs/"
# Windows launcher and its icon: dead weight on Linux.
rm "$OUTPUT_DIR/usr/share/spotbugs/bin/spotbugs.bat" "$OUTPUT_DIR/usr/share/spotbugs/bin/spotbugs.ico"

# bin/spotbugs locates its home from $0, so exec it by its real path.
cat > "$OUTPUT_DIR/usr/bin/spotbugs" << 'WRAPPER'
#!/bin/sh
exec /usr/share/spotbugs/bin/spotbugs "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/spotbugs"
