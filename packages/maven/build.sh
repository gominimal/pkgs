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
  # libutil.so.1 for openpty (its only libutil symbol), recorded in BOTH
  # DT_NEEDED and the version-needs table (.gnu.version_r: "required from
  # libutil.so.1: GLIBC_2.2.5"). Since glibc 2.34 openpty lives in libc at
  # that same version and libutil.so.1 is an empty stub, so minimal-check's
  # missing-runtime_deps reports openpty missing. --replace-needed renames
  # the file in both places, pointing the requirement at libc.so.6, which
  # defines it. (--remove-needed only drops DT_NEEDED, leaving a version
  # requirement on a library that is no longer loaded.)
  JLINE_LIB="$JLINE_DIR/Linux/$JLINE_ARCH/libjlinenative.so"
  patchelf --replace-needed libutil.so.1 libc.so.6 "$JLINE_LIB"
  # Fail closed if either table still names libutil.
  if patchelf --print-needed "$JLINE_LIB" | grep -qx libutil.so.1 \
     || objdump -p "$JLINE_LIB" | grep -q 'required from libutil'; then
    echo "libjlinenative.so still depends on libutil.so.1" >&2
    exit 1
  fi
fi

# Create wrapper script that sets M2_HOME
cat > $OUTPUT_DIR/usr/bin/mvn << 'EOF'
#!/bin/sh
export M2_HOME=/usr/share/maven
exec /usr/share/maven/bin/mvn "$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/mvn
