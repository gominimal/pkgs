#!/bin/sh
set -eu

JAR="checkstyle-${MINIMAL_ARG_VERSION}-all.jar"
test -f "$JAR"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/checkstyle"
cp "$JAR" "$OUTPUT_DIR/usr/share/checkstyle/checkstyle.jar"

cat > "$OUTPUT_DIR/usr/bin/checkstyle" << 'WRAPPER'
#!/bin/sh
exec java -jar /usr/share/checkstyle/checkstyle.jar "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/checkstyle"
