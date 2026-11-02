#!/bin/sh
set -eu

unzip -q "pmd-dist-${MINIMAL_ARG_VERSION}-bin.zip"
SRC="pmd-bin-${MINIMAL_ARG_VERSION}"
test -x "$SRC/bin/pmd"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/pmd"
cp -r "$SRC"/* "$OUTPUT_DIR/usr/share/pmd/"
# Windows launcher: dead weight on Linux.
rm "$OUTPUT_DIR/usr/share/pmd/bin/pmd.bat"

# bin/pmd locates PMD_HOME from $0, so exec it by its real path.
cat > "$OUTPUT_DIR/usr/bin/pmd" << 'WRAPPER'
#!/bin/sh
exec /usr/share/pmd/bin/pmd "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/pmd"
