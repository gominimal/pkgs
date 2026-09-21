#!/bin/bash
# jamvm-1.5.1: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 .. 25).
# JamVM 1.5.1, a C JVM, against classpath-0.93.
set -eu
trap 'echo "jamvm-1.5.1: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/jamvm-1.5.1"
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
[ "$(uname -m)" = x86_64 ] || { echo "jamvm-1.5.1: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum zip; do
  command -v "$t" >/dev/null 2>&1 || { echo "jamvm-1.5.1: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "jamvm-1.5.1: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "jamvm-1.5.1: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "jamvm-1.5.1: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/classpath-0.93/share/classpath/glibj.zip /usr/lib/jikes-1.22/bin/jikes; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "jamvm-1.5.1: libc.so fixup failed" >&2; exit 1; fi
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"
INC="-isystem ${SR}/include -isystem /usr/include"
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
cat > "${CCDIR}/gcc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGCC}" ${INC} -fcommon -Wno-error -std=gnu89 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion "\$@" ;; esac; done
exec "${BGCC}" ${INC} -fcommon -Wno-error -std=gnu89 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion "\$@" ${LNK}
WRAP
cat > "${CCDIR}/g++" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGXX}" ${INC} "\$@" ;; esac; done
exec "${BGXX}" ${INC} "\$@" ${LNK}
WRAP
chmod 0755 "${CCDIR}/gcc" "${CCDIR}/g++"
export CC="${CCDIR}/gcc" CXX="${CCDIR}/g++"

CP=/usr/lib/classpath-0.93
# --- P2 build ---
mkdir src && tar -xzf jamvm-1.5.1.tar.gz -C src --strip-components=1
cd src
CFLAGS="-O2" ./configure --prefix="${PREFIX}" --with-classpath-install-dir="${CP}" --disable-int-caching --enable-runtime-reloc > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "jamvm-1.5.1: configure failed" >&2; exit 1; }
make -j"${JOBS}" > ../make.log 2>&1 || { grep -n -m5 -iE ' error|Error [0-9]' ../make.log >&2 || true; tail -20 ../make.log >&2; echo "jamvm-1.5.1: make failed" >&2; exit 1; }
make install DESTDIR="${OUTPUT_DIR}" > ../install.log 2>&1 || { tail -20 ../install.log >&2; echo "jamvm-1.5.1: install failed" >&2; exit 1; }
cd "${BUILDROOT}"
# --- P3 gate: run a class compiled by jikes against glibj ---
mkdir -p gate; printf 'public class G { public static void main(String[] a){ int s=0; for(int i=1;i<=6;i++) s+=i; System.out.println("JAMVM:"+s+":"+System.getProperty("java.vm.name")); } }\n' > gate/G.java
/usr/lib/jikes-1.22/bin/jikes -bootclasspath "${CP}/share/classpath/glibj.zip" -d gate gate/G.java
# The compiled-in boot classpath names the final prefix, which does not exist under DESTDIR yet.
OUT="$("${DST}/bin/jamvm" ${JVMFLAGS} -Xbootclasspath:"${DST}/share/jamvm/classes.zip:${CP}/share/classpath/glibj.zip" -cp gate G 2>&1 | tail -1)"
case "$OUT" in JAMVM:21:*) ;; *) echo "jamvm-1.5.1: gate printed '$OUT'" >&2; exit 1 ;; esac

mkdir -p "${OUTPUT_DIR}/usr/share/jamvm-1.5.1"
cat > "${OUTPUT_DIR}/usr/share/jamvm-1.5.1/BUILDINFO" <<EOF
jamvm-1.5.1
source: jamvm-1.5.1.tar.gz
classpath: /usr/lib/classpath-0.93
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "jamvm-1.5.1: installed to ${PREFIX}"
