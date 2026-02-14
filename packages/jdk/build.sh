#!/bin/sh
set -ex

tar xf "OpenJDK21U-jdk_x64_linux_hotspot_${MINIMAL_ARG_VERSION}_${MINIMAL_ARG_BUILD_NUM}.tar.gz"
cd "jdk-${MINIMAL_ARG_VERSION}+${MINIMAL_ARG_BUILD_NUM}"

mkdir -p $OUTPUT_DIR/usr/{bin,lib/jvm}

# Install the JDK
cp -r . $OUTPUT_DIR/usr/lib/jvm/

# Symlink key binaries
for bin in java javac jar jlink jmod jpackage jshell keytool; do
    ln -sv ../lib/jvm/bin/$bin $OUTPUT_DIR/usr/bin/$bin
done
