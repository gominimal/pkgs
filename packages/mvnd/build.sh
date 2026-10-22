#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  PLATFORM="amd64" ;;
  aarch64) PLATFORM="aarch64" ;;
  *)       echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

DIST="maven-mvnd-${MINIMAL_ARG_VERSION}-linux-${PLATFORM}"
tar -xof "${DIST}.tar.gz"

# Fail closed if upstream changes the Maven it embeds without this package
# noticing: the version is pinned in build.ncl and asserted by the tests.
test -f "${DIST}/mvn/lib/maven-core-${MINIMAL_ARG_MAVEN_VERSION}.jar"

INSTALL="$OUTPUT_DIR/usr/share/mvnd"
mkdir -p "$OUTPUT_DIR/usr/bin" "$INSTALL"
cp -r "${DIST}"/. "$INSTALL/"

# Windows-only payload: .cmd launchers and jansi's Windows DLLs.
find "$INSTALL" -name '*.cmd' -delete
find "$INSTALL/mvn/lib/jansi-native" -mindepth 1 -maxdepth 1 -type d -name Windows -exec rm -rf {} +

# Wrapper. bin/mvnd is the GraalVM native client; it spawns the daemon, a
# JVM, from $JAVA_HOME. Default JAVA_HOME to the packaged jdk and pin
# MVND_HOME so the client finds its daemon jars and embedded Maven.
# The embedded Maven's own bin/mvn is deliberately NOT put on PATH: the
# `maven` package owns /usr/bin/mvn.
# MAVEN_REPO_LOCAL is the local repository the `maven` package wires to a
# session state dir. mvnd has no environment binding for it, so forward it
# as -Dmaven.repo.local, the way /usr/bin/mvn does: with both packages in a
# session, mvn and mvnd then share one repository instead of downloading
# everything twice. A -Dmaven.repo.local the caller passes comes later and
# still wins. (Daemon state needs no forwarding: the client reads
# MVND_DAEMON_STORAGE itself; see env_state_wiring in build.ncl.)
cat > "$OUTPUT_DIR/usr/bin/mvnd" << 'EOF'
#!/bin/sh
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm}"
export MVND_HOME=/usr/share/mvnd
if [ -n "${MAVEN_REPO_LOCAL:-}" ]; then
  exec /usr/share/mvnd/bin/mvnd "-Dmaven.repo.local=$MAVEN_REPO_LOCAL" "$@"
fi
exec /usr/share/mvnd/bin/mvnd "$@"
EOF
chmod 0755 "$OUTPUT_DIR/usr/bin/mvnd"
