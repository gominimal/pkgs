#!/bin/bash
# icedtea-8: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 .. 25).
# OpenJDK 8u292 via the IcedTea 3.19.0 harness in --enable-bootstrap mode, with ../icedtea-7 as the boot JDK.
set -eu
trap 'echo "icedtea-8: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/icedtea-8"
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
[ "$(uname -m)" = x86_64 ] || { echo "icedtea-8: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum gawk xz gzip patch zip unzip cpio file which pkg-config objcopy readelf; do
  command -v "$t" >/dev/null 2>&1 || { echo "icedtea-8: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "icedtea-8: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "icedtea-8: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "icedtea-8: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/icedtea-7/bin/javac /usr/lib/icedtea-7/bin/java /usr/lib/ant-bootstrap-1.8.4/bin/ant /usr/include/freetype2/freetype/freetype.h /usr/include/X11/Intrinsic.h; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "icedtea-8: libc.so fixup failed" >&2; exit 1; fi
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"
INC="-isystem ${SR}/include -isystem /usr/include"
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
cat > "${CCDIR}/gcc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGCC}" ${INC}  "\$@" ;; esac; done
exec "${BGCC}" ${INC}  "\$@" ${LNK}
WRAP
cat > "${CCDIR}/g++" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGXX}" ${INC} "\$@" ;; esac; done
exec "${BGXX}" ${INC} "\$@" ${LNK}
WRAP
chmod 0755 "${CCDIR}/gcc" "${CCDIR}/g++"
export CC="${CCDIR}/gcc" CXX="${CCDIR}/g++"

JDK7=/usr/lib/icedtea-7; ANT=/usr/lib/ant-bootstrap-1.8.4
# --- P2 unpack: the harness, then the ten drops where its configure expects them ---
mkdir src && tar -xJf icedtea-3.19.0.tar.xz -C src --strip-components=1
cd src
mkdir openjdk.src && tar -xJf ../icedtea8-3.19.0-openjdk.tar.xz -C openjdk.src --strip-components=1
for d in aarch32 corba jaxp jaxws jdk langtools hotspot nashorn shenandoah; do mkdir -p "openjdk.src/$d" && tar -xJf "../icedtea8-3.19.0-$d.tar.xz" -C "openjdk.src/$d" --strip-components=1; done
( cd openjdk.src/jdk && patch -p1 < ../../../jdk-currency-time-bomb2.patch )
# --- source fixes ---
sed -i -E 's/(DIST_ID="Custom build).*$/\1"/' configure acinclude.m4
sed -i 's/DIST_NAME="\$build_os"/DIST_NAME="minimal"/' configure acinclude.m4
sed -i 's|#include <sys/sysctl.h>|#include <linux/sysctl.h>|' openjdk.src/jdk/src/solaris/native/java/net/PlainSocketImpl.c openjdk.src/jdk/src/solaris/native/java/net/PlainDatagramSocketImpl.c
grep -q 'DIST_NAME="minimal"' configure && grep -q 'linux/sysctl.h' openjdk.src/jdk/src/solaris/native/java/net/PlainSocketImpl.c || { echo "icedtea-8: a source fix did not apply" >&2; exit 1; }
# the boot JDK's tools on PATH; hotspot takes gcc/g++ from PATH (hence CCDIR), the jdk makefiles from CC/CXX
export JAVA_HOME="${JDK7}" PATH="${JDK7}/bin:${ANT}/bin:${CCDIR}:${PATH}" ANT_HOME="${ANT}" ANT_OPTS="-Xmx8g" DISABLE_HOTSPOT_OS_VERSION_CHECK=ok
# --- configure + make ---
./configure "CFLAGS=-fcommon -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=int-conversion" "CXXFLAGS=-fcommon" \
  --enable-bootstrap --disable-downloading --disable-tests --disable-docs --disable-nss \
  --disable-system-sctp --disable-system-pcsc --disable-system-kerberos --disable-system-gif --disable-system-jpeg --disable-system-png --enable-system-zlib --enable-system-lcms \
  --with-parallel-jobs="${JOBS}" --with-openjdk-src-dir=./openjdk.src --with-jdk-home="${JDK7}" > ../configure.log 2>&1 \
  || { grep -n -iE 'error|cannot|not found|no acceptable' ../configure.log | tail -8 >&2 || true; tail -10 ../configure.log >&2; echo "icedtea-8: configure failed" >&2; exit 1; }
make -j"${JOBS}" > ../make.log 2>&1 \
  || { grep -n -B8 -m1 -E 'make\[[0-9]*\]: \*\*\*|^\*\*\* \[' ../make.log | tail -12 >&2 || true; grep -oE 'error: [^(]{0,60}|Exception in thread[^\n]{0,60}|\*\*\* \[[^]]{0,60}\]' ../make.log | sort | uniq -c | sort -rn | head -5 >&2 || true; echo "icedtea-8: make failed" >&2; exit 1; }
[ -x openjdk.build/images/j2sdk-image/bin/java ] || { echo "icedtea-8: no j2sdk-image" >&2; exit 1; }
mkdir -p "${DST}" && cp -a openjdk.build/images/j2sdk-image/. "${DST}/"
cd "${BUILDROOT}"
# --- P3 gate: lambdas and streams compile and run on the new JDK ---
mkdir -p gate; printf 'import java.util.stream.*;\npublic class G { public static void main(String[] a){ int s = IntStream.rangeClosed(1,6).map(x -> x).sum(); Runnable r = () -> System.out.println("IT8:"+s+":"+System.getProperty("java.version").substring(0,3)); r.run(); } }\n' > gate/G.java
( cd gate && "${DST}/bin/javac" G.java )
OUT="$("${DST}/bin/java" -cp gate G 2>&1 | tail -1)"
[ "$OUT" = "IT8:21:1.8" ] || { echo "icedtea-8: gate printed '$OUT'" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}/usr/share/icedtea-8"
cat > "${OUTPUT_DIR}/usr/share/icedtea-8/BUILDINFO" <<EOF
icedtea-8
source: icedtea-3.19.0.tar.xz + 10 OpenJDK drops + 1 patch
boot: icedtea-7 (OpenJDK 7u171); ant-bootstrap-1.8.4
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "icedtea-8: installed to ${PREFIX}"
