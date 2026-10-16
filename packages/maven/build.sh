#!/bin/sh
set -ex

tar -xof "apache-maven-${MINIMAL_ARG_VERSION}-bin.tar.gz"

mkdir -p $OUTPUT_DIR/usr/{bin,share/maven}
cp -r "apache-maven-${MINIMAL_ARG_VERSION}"/* $OUTPUT_DIR/usr/share/maven/

# 3.10.0+ ships JLine's native library prebuilt for 9 OS/arch pairs plus a
# Windows DLL. Keep only the one this arch can load; bin/mvn resolves it as
# $MAVEN_HOME/lib/jline-native/Linux/<arch>/libjlinenative.so.
case $(uname -m) in
  x86_64)  JLINE_ARCH="x86_64" ;;
  aarch64) JLINE_ARCH="arm64" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
JLINE_DIR="$OUTPUT_DIR/usr/share/maven/lib/jline-native"
if [ -d "$JLINE_DIR" ]; then
  test -f "$JLINE_DIR/Linux/$JLINE_ARCH/libjlinenative.so"
  mv "$JLINE_DIR/Linux/$JLINE_ARCH" "$JLINE_DIR/.keep"
  find "$JLINE_DIR" -mindepth 1 -maxdepth 1 ! -name .keep -exec rm -rf {} +
  mkdir -p "$JLINE_DIR/Linux"
  mv "$JLINE_DIR/.keep" "$JLINE_DIR/Linux/$JLINE_ARCH"
  # The prebuilt lib was linked against a pre-2.34 glibc: it NEEDs
  # libutil.so.1 for openpty, its only libutil symbol. Since glibc 2.34
  # openpty lives in libc (exported at the same GLIBC_2.2.5 / GLIBC_2.17
  # versions) and libutil.so.1 is an empty stub, which the missing-runtime_deps
  # checker rightly reports as not providing it. The lib already NEEDs
  # libc.so.6, so drop the stale entry rather than chase the stub.
  patchelf --remove-needed libutil.so.1 "$JLINE_DIR/Linux/$JLINE_ARCH/libjlinenative.so"
fi

# Create wrapper script that sets M2_HOME
cat > $OUTPUT_DIR/usr/bin/mvn << 'EOF'
#!/bin/sh
export M2_HOME=/usr/share/maven
exec /usr/share/maven/bin/mvn "$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/mvn
