#!/bin/sh
set -eu

# Apalache, the symbolic model checker for TLA+ and Quint: the upstream release
# distribution (one fat jar + a bash launcher), run on our jdk. See build.ncl for
# why this is the release artifact and not a source build.

V="${MINIMAL_ARG_VERSION:?build.ncl forwards version}"

tar -xzof "apalache-$V.tgz"
src="apalache-$V"
test -f "$src/lib/apalache.jar"
test -f "$src/bin/apalache-mc"

# The tree keeps upstream's layout (bin/apalache-mc, lib/apalache.jar) under a
# directory named `apalache`: that is the layout quint looks for
# (<dist dir>/apalache/bin/apalache-mc, <dist dir>/apalache/lib/apalache.jar).
dest="$OUTPUT_DIR/usr/lib/apalache"
mkdir -p "$dest/bin" "$dest/lib" "$OUTPUT_DIR/usr/bin"
install -m 0644 "$src/lib/apalache.jar" "$dest/lib/apalache.jar"
install -m 0644 "$src/LICENSE" "$dest/LICENSE"

# The launcher runs `java` from PATH (once to probe a JVM flag, once to exec).
# Pin both to the packaged JDK's java, so the java on a user's PATH (or none)
# never decides which JVM runs apalache.
java=/usr/lib/jvm/bin/java
launcher="$dest/bin/apalache-mc"
sed \
  -e 's|^if java --sun-misc-unsafe-memory-access=allow -version |if "$APALACHE_JAVA" --sun-misc-unsafe-memory-access=allow -version |' \
  -e 's|^exec java \$JVM_COMPAT_ARGS |exec "$APALACHE_JAVA" $JVM_COMPAT_ARGS |' \
  -e "s|^APALACHE_JAR=.*|&\nAPALACHE_JAVA=$java # minimal: the packaged jdk, not the one on PATH|" \
  "$src/bin/apalache-mc" > "$launcher"
chmod 0755 "$launcher"

# Fail closed: both java invocations were rewritten and no bare `java` is left.
[ "$(grep -c '"$APALACHE_JAVA"' "$launcher")" = 2 ] ||
  { echo "apalache-mc: the java patch did not apply to both invocations — re-check the launcher" >&2; exit 1; }
[ "$(grep -c "^APALACHE_JAVA=$java " "$launcher")" = 1 ] ||
  { echo "apalache-mc: APALACHE_JAVA was not set" >&2; exit 1; }
if grep -nE '(^|[[:space:]])java[[:space:]]' "$launcher"; then
  echo "apalache-mc: a bare java invocation is left in the launcher" >&2
  exit 1
fi

# The launcher resolves its own symlink to find ../lib/apalache.jar.
ln -s ../lib/apalache/bin/apalache-mc "$OUTPUT_DIR/usr/bin/apalache-mc"
