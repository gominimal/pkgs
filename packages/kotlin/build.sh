#!/bin/sh
set -ex

# Upstream's compiler distribution is pure JVM: launcher scripts plus jars.
# The launchers resolve KOTLIN_HOME by following their own symlinks
# (findKotlinHome), so the /usr/bin entries can be plain symlinks.
unzip -q "kotlin-compiler-${MINIMAL_ARG_VERSION}.zip"

mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/kotlin"
cp -r kotlinc/. "$OUTPUT_DIR/usr/share/kotlin/"
rm -f "$OUTPUT_DIR"/usr/share/kotlin/bin/*.bat

# Don't trust the zip's mode bits; pin them.
chmod 0755 "$OUTPUT_DIR"/usr/share/kotlin/bin/*
for bin in "$OUTPUT_DIR"/usr/share/kotlin/bin/*; do
  name=$(basename "$bin")
  ln -s "../share/kotlin/bin/$name" "$OUTPUT_DIR/usr/bin/$name"
done

# Fail closed if upstream moves the layout.
test -x "$OUTPUT_DIR/usr/share/kotlin/bin/kotlinc"
test -f "$OUTPUT_DIR/usr/share/kotlin/lib/kotlin-compiler.jar"
