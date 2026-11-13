#!/bin/sh
set -ex

# The platform-independent bundle: bin/jbang (bash launcher), bin/jbang.jar,
# plus .cmd/.ps1 launchers for Windows.
tar -xof "jbang-${MINIMAL_ARG_VERSION}.tar"
SRC="jbang-${MINIMAL_ARG_VERSION}"

INSTALL="$OUTPUT_DIR/usr/share/jbang"
mkdir -p "$OUTPUT_DIR/usr/bin" "$INSTALL/bin"
install -m 0755 "$SRC/bin/jbang" "$INSTALL/bin/jbang"
install -m 0644 "$SRC/bin/jbang.jar" "$INSTALL/bin/jbang.jar"
install -m 0644 "$SRC/version.txt" "$INSTALL/version.txt"

# Wrapper. The upstream launcher looks for a JDK in $JAVA_HOME, then javac
# on PATH, and only if both fail does it DOWNLOAD one from foojay.io into
# ~/.jbang. Point JAVA_HOME at the packaged jdk (unless the caller set one)
# so the download path is never taken.
cat > "$OUTPUT_DIR/usr/bin/jbang" << 'EOF'
#!/bin/sh
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm}"
exec /usr/share/jbang/bin/jbang "$@"
EOF
chmod 0755 "$OUTPUT_DIR/usr/bin/jbang"

# Fail closed if the bundle layout changes.
test -s "$INSTALL/bin/jbang.jar"
grep -qx "${MINIMAL_ARG_VERSION}" "$INSTALL/version.txt"
