#!/bin/sh
set -eu

JAR="google-java-format-${MINIMAL_ARG_VERSION}-all-deps.jar"
test -f "$JAR"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/google-java-format"
cp "$JAR" "$OUTPUT_DIR/usr/share/google-java-format/google-java-format.jar"

cat > "$OUTPUT_DIR/usr/bin/google-java-format" << 'WRAPPER'
#!/bin/sh
exec java -jar /usr/share/google-java-format/google-java-format.jar "$@"
WRAPPER
chmod +x "$OUTPUT_DIR/usr/bin/google-java-format"
