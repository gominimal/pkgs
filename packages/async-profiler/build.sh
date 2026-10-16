#!/bin/sh
# Builds async-profiler from source: the native agent (libasyncProfiler.so)
# and the asprof launcher with upstream's Makefile, then the two jars and the
# jfrconv launcher by hand so the jars are reproducible (see below).
#
# Upstream's `make all` downloads nothing; only the test targets fetch jars.
set -eux

TOP=$(pwd)
export JAVA_HOME=/usr/lib/jvm
# asprof and jattach print __DATE__ in --version; gcc takes it from here.
# 2026-07-20, the v4.5 release date.
export SOURCE_DATE_EPOCH=1784505600

REPRO="-ffile-prefix-map=$TOP=/builddir -gno-record-gcc-switches -Wl,--build-id=none"

# --- helper classes ---------------------------------------------------------
# src/helper/one/profiler/*.class are committed, prebuilt class files that the
# agent embeds with .incbin and injects into the target JVM. Rebuild them from
# the .java next to them, exactly as upstream's `%.class: %.java` rule does
# (-source/-target 8, not --release 8: JfrSync uses jdk.jfr, which the Java 8
# API signature does not have).
for src in src/helper/one/profiler/*.java; do
  rm -f "${src%.java}.class"
  "$JAVA_HOME/bin/javac" -source 8 -target 8 -Xlint:-options -g:none "$src"
done

# --- native: libasyncProfiler.so + asprof ------------------------------------
# The Makefile's recipes take no LDFLAGS, so the linker flag rides in the
# *_EXTRA compiler flags (both are passed to the link). The .so is linked with
# -static-libstdc++ -static-libgcc by upstream, so it needs only glibc.
# CC/CXX on the command line: make's built-in CC=cc beats the Makefile's
# `CC ?= gcc`, and there is no `cc` here.
make -j"$(nproc)" \
  CC=gcc CXX=g++ \
  JAVA_HOME="$JAVA_HOME" \
  CFLAGS_EXTRA="$REPRO" \
  CXXFLAGS_EXTRA="$REPRO" \
  build/bin build/lib build/lib/libasyncProfiler.so build/bin/asprof

# Upstream's release strips debug info from the .so (and ships it separately).
strip -g build/lib/libasyncProfiler.so

# --- jars -------------------------------------------------------------------
# Upstream builds these with `jar cfm` / `jar cfe`, which stamps the build time
# on every entry and walks directories in filesystem order. DeterministicJar
# writes sorted entries with one fixed timestamp instead.
javac_opts="--release 8 -Xlint:-options -encoding UTF-8"

rm -rf build/api && mkdir -p build/api build/jar
find src/api/one/profiler -name '*.java' | LC_ALL=C sort > build/api-sources.txt
"$JAVA_HOME/bin/javac" $javac_opts -d build/api @build/api-sources.txt
{
  printf 'Manifest-Version: 1.0\n'
  cat src/api/META-INF/MANIFEST.MF
} > build/api-manifest.txt
"$JAVA_HOME/bin/java" "$TOP/DeterministicJar.java" \
  build/jar/async-profiler.jar build/api-manifest.txt build/api

# jfr-converter.jar = converter classes + the html templates in src/res + the
# native-image metadata in src/converter/META-INF (upstream: -C each of them).
rm -rf build/converter && mkdir -p build/converter
find src/converter -name '*.java' | LC_ALL=C sort > build/converter-sources.txt
"$JAVA_HOME/bin/javac" $javac_opts -d build/converter @build/converter-sources.txt
cp src/res/* build/converter/
cp -R src/converter/META-INF build/converter/
printf 'Manifest-Version: 1.0\nMain-Class: one.convert.Main\n' > build/converter-manifest.txt
"$JAVA_HOME/bin/java" "$TOP/DeterministicJar.java" \
  build/jar/jfr-converter.jar build/converter-manifest.txt build/converter

# jfrconv: upstream's shell launcher with the converter jar appended to it
# (the launcher runs `java -jar "$0"`). BUILD_DATE comes from the fixed epoch.
build_date=$(date -u -d "@$SOURCE_DATE_EPOCH" "+%b %d %Y")
sed -e "s/PROFILER_VERSION/$MINIMAL_ARG_VERSION/g" -e "s/BUILD_DATE/$build_date/g" \
  src/launcher/launcher.sh > build/bin/jfrconv
cat build/jar/jfr-converter.jar >> build/bin/jfrconv

# --- install ----------------------------------------------------------------
# asprof finds the agent at ../lib/libasyncProfiler.so relative to its own
# path, so /usr/bin + /usr/lib keeps upstream's bin/ + lib/ relationship.
install -Dm0755 build/bin/asprof "$OUTPUT_DIR/usr/bin/asprof"
install -Dm0755 build/bin/jfrconv "$OUTPUT_DIR/usr/bin/jfrconv"
install -Dm0755 build/lib/libasyncProfiler.so "$OUTPUT_DIR/usr/lib/libasyncProfiler.so"
install -Dm0644 src/asprof.h "$OUTPUT_DIR/usr/include/asprof.h"
install -Dm0644 build/jar/async-profiler.jar "$OUTPUT_DIR/usr/share/async-profiler/async-profiler.jar"
install -Dm0644 build/jar/jfr-converter.jar "$OUTPUT_DIR/usr/share/async-profiler/jfr-converter.jar"
