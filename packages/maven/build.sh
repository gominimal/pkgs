#!/bin/sh
set -ex

tar -xof "apache-maven-${MINIMAL_ARG_VERSION}-bin.tar.gz"

mkdir -p $OUTPUT_DIR/usr/{bin,share/maven}
cp -r "apache-maven-${MINIMAL_ARG_VERSION}"/* $OUTPUT_DIR/usr/share/maven/

# 3.10.0 shipped JLine's native terminal library prebuilt for 9 OS/arch pairs
# (lib/jline-native); 3.10.1 dropped it and bin/mvn no longer points JLine at
# it. Maven is now Java and shell only, so the recipe has no OutputLib and no
# glibc runtime dep. Fail if a shared object comes back rather than ship one
# the outputs don't declare and nothing links.
so=$(find "$OUTPUT_DIR/usr/share/maven" \( -name '*.so' -o -name '*.so.*' -o -name '*.dll' \) -print)
if [ -n "$so" ]; then
  echo "maven ships native libraries again; restore the jline_native output:" >&2
  echo "$so" >&2
  exit 1
fi

# Create wrapper script that sets M2_HOME
cat > $OUTPUT_DIR/usr/bin/mvn << 'EOF'
#!/bin/sh
export M2_HOME=/usr/share/maven
# MAVEN_REPO_LOCAL is the session state dir minimal wires for this package
# (attrs.env_state_wiring). Maven has no env var for its local repository,
# so pass it as -Dmaven.repo.local; a -Dmaven.repo.local the caller passes
# comes later on the command line and still wins. When it is set it also
# overrides a <localRepository> in the user's settings.xml (a -D system
# property beats settings), which is intended: the state dir is the one
# repository a session keeps.
if [ -n "${MAVEN_REPO_LOCAL:-}" ]; then
  exec /usr/share/maven/bin/mvn "-Dmaven.repo.local=$MAVEN_REPO_LOCAL" "$@"
fi
exec /usr/share/maven/bin/mvn "$@"
EOF
chmod +x $OUTPUT_DIR/usr/bin/mvn
