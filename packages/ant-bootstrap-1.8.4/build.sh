#!/bin/bash
# ant-bootstrap-1.8.4: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# Apache Ant 1.8.4 built by jikes and run on jamvm-1.5.1 (bootstrap.sh); its jars feed the ecj compiles.
set -eu
trap 'echo "ant-bootstrap-1.8.4: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ant-bootstrap-1.8.4"
DST="${OUTPUT_DIR}${PREFIX}"
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"
export TMPDIR="${BUILDROOT}/tmp"; mkdir -p "$TMPDIR"
export TAR_OPTIONS=--no-same-owner   # the sandbox cannot chown
JVMFLAGS="-Xnocompact -Xnoinlining"   # jamvm: without these the class-library builds can hang

# --- P0 preconditions ---
[ "$(uname -m)" = x86_64 ] || { echo "ant-bootstrap-1.8.4: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum bzip2; do
  command -v "$t" >/dev/null 2>&1 || { echo "ant-bootstrap-1.8.4: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ant-bootstrap-1.8.4: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ant-bootstrap-1.8.4: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ant-bootstrap-1.8.4: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/jikes-1.22/bin/jikes /usr/lib/jamvm-1.5.1/bin/jamvm /usr/lib/classpath-0.93/share/classpath/glibj.zip; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "ant-bootstrap-1.8.4: libc.so fixup failed" >&2; exit 1; fi
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"
INC="-isystem ${SR}/include -isystem /usr/include"
# C++: /usr/include must stay behind the libstdc++ headers, whose <cmath> reaches math.h with #include_next
CXXINC="-isystem ${SR}/include -idirafter /usr/include"
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
cat > "${CCDIR}/gcc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGCC}" ${INC}  "\$@" ;; esac; done
exec "${BGCC}" ${INC}  "\$@" ${LNK}
WRAP
cat > "${CCDIR}/g++" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGXX}" ${CXXINC} "\$@" ;; esac; done
exec "${BGXX}" ${CXXINC} "\$@" ${LNK}
WRAP
chmod 0755 "${CCDIR}/gcc" "${CCDIR}/g++"
export CC="${CCDIR}/gcc" CXX="${CCDIR}/g++"

JIKES=/usr/lib/jikes-1.22/bin/jikes; JAMVM=/usr/lib/jamvm-1.5.1/bin/jamvm; GLIBJ=/usr/lib/classpath-0.93/share/classpath/glibj.zip
# --- P2 build ---
mkdir src && tar -xjf apache-ant-1.8.4-src.tar.bz2 -C src --strip-components=1
cd src
# bootstrap.sh resolves `jikes` through PATH (build.compiler=jikes); the tests need a JDK this stack lacks
mkdir -p "${BUILDROOT}/bin"; ln -sf "${JIKES}" "${BUILDROOT}/bin/jikes"
export PATH="${BUILDROOT}/bin:${PATH}" JAVA_HOME=/usr/lib/jamvm-1.5.1 JAVACMD="${JAMVM}" JAVAC="${JIKES}" CLASSPATH="${GLIBJ}"
export ANT_OPTS="-Dbuild.compiler=jikes" BOOTJAVAC_OPTS="-nowarn"
: > "${HOME}/.ant.properties"
sed -i "s|^\"\${JAVACMD}\" |\"\${JAVACMD}\" ${JVMFLAGS} |" bootstrap.sh
sed -i 's|depends="jars,test-jar"|depends="jars"|' build.xml
bash bootstrap.sh -Ddist.dir="${DST}" > ../bootstrap.log 2>&1 || { grep -B1 -A3 -m3 -E 'error|Error|Exception' ../bootstrap.log | head -20 >&2; echo "ant-bootstrap-1.8.4: bootstrap.sh failed" >&2; exit 1; }
unset CLASSPATH
cd "${BUILDROOT}"
# --- P3 gate ---
[ -s "${DST}/lib/ant.jar" ] || { echo "ant-bootstrap-1.8.4: lib/ant.jar missing" >&2; exit 1; }
[ "$(ls "${DST}"/lib/*.jar | wc -l)" -ge 5 ] || { echo "ant-bootstrap-1.8.4: too few jars" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}/usr/share/ant-bootstrap-1.8.4"
cat > "${OUTPUT_DIR}/usr/share/ant-bootstrap-1.8.4/BUILDINFO" <<EOF
ant-bootstrap-1.8.4
source: apache-ant-1.8.4-src.tar.bz2
compiler: jikes-1.22 on jamvm-1.5.1
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "ant-bootstrap-1.8.4: installed to ${PREFIX}"
