#!/bin/sh
# Builds tla2tools.jar from source with the JDK alone (javac + jar), mirroring
# upstream's Ant `compile` + `dist` targets in
# tlatools/org.lamport.tlatools/customBuild.xml. Upstream's release pipeline
# drives that Ant file through Maven/Tycho, which would need Eclipse p2 and
# Maven Central at build time; the Ant targets themselves need nothing but the
# JDK and the javax.mail jars vendored in the source tree's lib/ directory, so
# the build is offline and needs neither Ant nor Maven.
set -eu

TOP=$(pwd)
cd tlatools/org.lamport.tlatools

ROOT=$(pwd)
CLASSES="$ROOT/minimal-classes"
MAILJAR=lib/javax.mail/mailapi-1.6.3.jar
rm -rf "$CLASSES"
mkdir -p "$CLASSES"

# --- compile (customBuild.xml target "compile") ------------------------------
# Upstream compiles with source/target 1.8 and debug=true. Sorted source list
# so the javac invocation does not depend on directory order.
find src -name '*.java' | LC_ALL=C sort > "$ROOT/sources.txt"
javac -nowarn -Xlint:-options -encoding UTF-8 -g \
  -source 1.8 -target 1.8 \
  -cp "$MAILJAR" -d "$CLASSES" @"$ROOT/sources.txt"

# Resources: Ant copies src/**/*.* minus *.java, editor backups, the stale
# javacc snapshots (*.09-09-07 ...), *.jpg, and its default excludes
# (.gitignore).
(cd src && find . -type f -name '*.*' | LC_ALL=C sort) | while IFS= read -r f; do
  case "$f" in
    *.java | *.jpg | *'.~'* | *'##'* | *.09-09-07 | *.09-07-02 | *.11-02-10 | */.gitignore) continue ;;
  esac
  mkdir -p "$CLASSES/$(dirname "$f")"
  cp "src/$f" "$CLASSES/$f"
done

# --- dist (customBuild.xml target "dist") ------------------------------------
# javax.mail backs TLC's -mail option; upstream folds these three vendored jars
# into tla2tools.jar. Extract each into a scratch dir and keep what the Ant
# patternsets keep.
extract() { # jar, scratch dir
  rm -rf "$2" && mkdir -p "$2"
  (cd "$2" && jar --extract --file "$ROOT/$1")
}
extract lib/javax.mail/mailapi-1.6.3.jar "$ROOT/x-mailapi"
rm -rf "$ROOT/x-mailapi/javax/mail/search"
extract lib/javax.mail/smtp-1.6.3.jar "$ROOT/x-smtp"
extract lib/javax.mail/javax.activation_1.1.0.v201211130549.jar "$ROOT/x-activation"
rm -rf "$ROOT/x-activation/org"
for d in x-mailapi x-smtp x-activation; do
  (cd "$ROOT/$d" && find . -type f -name '*.class' | LC_ALL=C sort) | while IFS= read -r f; do
    mkdir -p "$CLASSES/$(dirname "$f")"
    cp "$ROOT/$d/$f" "$CLASSES/$f"
  done
done
mkdir -p "$CLASSES/META-INF"
for f in LICENSE.txt mailcap javamail.charset.map; do
  cp "$ROOT/x-mailapi/META-INF/$f" "$CLASSES/META-INF/$f"
done
: > "$CLASSES/META-INF/javamail.default.address.map"
cp doc/License.txt "$CLASSES/License.txt"

# Ant's jar-level excludes.
rm -f "$CLASSES/README.txt" "$CLASSES/heapstats.jfc" "$CLASSES/jpf.properties"
rm -f "$CLASSES"/tlc2/tool/fp/*.tla "$CLASSES"/tlc2/value/*.tla "$CLASSES"/pcal/*.tla
rm -rf "$CLASSES/META-INF/maven"

# Upstream's manifest minus the fields that stamp the build host, user and
# date (Built-By, Ant-Version, Implementation-Version's TODAY). The git fields
# are the release tag's; TLCGlobals.getRevision() reads X-Git-ShortRevision.
short_rev=$(printf '%s' "$MINIMAL_ARG_COMMIT" | cut -c1-7)
cat > "$ROOT/manifest.txt" <<EOF
Manifest-Version: 1.0
Implementation-Title: TLA+ Tools
Implementation-Version: $MINIMAL_ARG_VERSION
Implementation-Vendor: Microsoft Corp.
Main-class: tlc2.TLC
Class-Path: CommunityModules.jar
X-Git-Tag: v$MINIMAL_ARG_VERSION
X-Git-Revision: $MINIMAL_ARG_COMMIT
X-Git-ShortRevision: $short_rev
Application-Name: TLC
permissions: all-permissions
EOF

# Reproducible jar: sorted entries, directory entries included, one fixed
# timestamp (see DeterministicJar.java for why `jar --create` can't do this).
mkdir -p "$OUTPUT_DIR/usr/share/tlaplus"
java "$TOP/DeterministicJar.java" \
  "$OUTPUT_DIR/usr/share/tlaplus/tla2tools.jar" "$ROOT/manifest.txt" "$CLASSES"

# --- launchers ---------------------------------------------------------------
# The jar's three main tools: tlc2.TLC (the manifest Main-class), tla2sany.SANY
# (parser / semantic checker) and pcal.trans (PlusCal translator). TLC prints a
# warning unless the JVM runs the parallel GC, and upstream's own TLCRunner
# passes -XX:+UseParallelGC, so the tlc launcher does too. tla2tex.TLA is not
# wrapped: it shells out to LaTeX, which this package does not ship.
mkdir -p "$OUTPUT_DIR/usr/bin"
launcher() { # name, main class, extra JVM flags
  cat > "$OUTPUT_DIR/usr/bin/$1" <<EOF
#!/bin/sh
# Set JAVA_OPTS for extra JVM flags, e.g. JAVA_OPTS=-Xmx8g.
exec java $3 \${JAVA_OPTS:-} -cp /usr/share/tlaplus/tla2tools.jar $2 "\$@"
EOF
  chmod 0755 "$OUTPUT_DIR/usr/bin/$1"
}
launcher tlc tlc2.TLC -XX:+UseParallelGC
launcher sany tla2sany.SANY ""
launcher pcal pcal.trans ""
