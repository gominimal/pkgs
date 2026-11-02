#!/bin/sh
set -eu

# The pure-JVM jar: a self-contained (shaded) jar with Main-Class
# it.mulders.mcs.App, compiled for Java 25 (class file version 69).
JAR="mcs-${MINIMAL_ARG_VERSION}.jar"
test -f "$JAR"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/mcs"
install -m 0644 "$JAR" "$OUTPUT_DIR/usr/share/mcs/mcs.jar"

cat > "$OUTPUT_DIR/usr/bin/mcs" << 'WRAPPER'
#!/bin/sh
exec java -jar /usr/share/mcs/mcs.jar "$@"
WRAPPER
chmod 0755 "$OUTPUT_DIR/usr/bin/mcs"
