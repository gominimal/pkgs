#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  PLATFORM="x64" ;;
  aarch64) PLATFORM="aarch64" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

tar -xof "OpenJDK27U-jdk_${PLATFORM}_linux_hotspot_${MINIMAL_ARG_VERSION}_${MINIMAL_ARG_BUILD_NUM}.tar.gz"
cd "jdk-${MINIMAL_ARG_VERSION}+${MINIMAL_ARG_BUILD_NUM}"

mkdir -p $OUTPUT_DIR/usr/{bin,lib/jvm}

# Install the JDK
cp -r . $OUTPUT_DIR/usr/lib/jvm/

# Put every JDK tool on PATH (jdb, jcmd, jfr, jstack, jmap, javap, jdeps,
# javadoc, ... -- not just the eight that used to be listed here).
for path in "$OUTPUT_DIR"/usr/lib/jvm/bin/*; do
    bin=$(basename "$path")
    ln -sv "../lib/jvm/bin/$bin" "$OUTPUT_DIR/usr/bin/$bin"
done
