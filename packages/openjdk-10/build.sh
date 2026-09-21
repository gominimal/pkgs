#!/bin/bash
# openjdk-10: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 .. 25).
# OpenJDK 10+46 from the GitHub tag archive, built with ../openjdk-9 as the boot JDK (with -XX:UseAVX=2: its AVX-512 intrinsics miscompile on AVX-512 hosts).
set -eu
trap 'echo "openjdk-10: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/openjdk-10"
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
[ "$(uname -m)" = x86_64 ] || { echo "openjdk-10: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum gzip gawk patch zip unzip cpio file which pkg-config objcopy readelf autoconf python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "openjdk-10: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "openjdk-10: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "openjdk-10: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "openjdk-10: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/openjdk-9/bin/javac /usr/lib/openjdk-9/bin/java /usr/include/gif_lib.h /usr/include/freetype2/freetype/freetype.h /usr/include/X11/Intrinsic.h; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "openjdk-10: libc.so fixup failed" >&2; exit 1; fi
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

BOOT=/usr/lib/openjdk-9
# --- P2 unpack (the GitHub tag archive; shipped binaries and jars removed, as Guix does) ---
mkdir src && tar -xzf jdk-10+46.tar.gz -C src --strip-components=1
cd src
find . -type f \( -name '*.bin' -o -name '*.exe' -o -name '*.jar' \) -delete
patch -p1 < ../openjdk-10-char-reproducibility.patch
patch -p1 < ../openjdk-10-classlist-reproducibility.patch
patch -p1 < ../openjdk-10-corba-reproducibility.patch
patch -p1 < ../openjdk-10-idlj-reproducibility.patch
patch -p1 < ../openjdk-10-module-reproducibility.patch
patch -p1 < ../openjdk-10-module3-reproducibility.patch
patch -p1 < ../openjdk-10-module4-reproducibility.patch
patch -p1 < ../openjdk-10-jar-reproducibility.patch
patch -p1 < ../openjdk-10-jtask-reproducibility.patch
patch -p1 < ../openjdk-10-pointer-comparison.patch
patch -p1 < ../openjdk-10-setsignalhandler.patch
patch -p1 < ../openjdk-currency-time-bomb2.patch
# --- source fixes ---
# the certificate converter is run as a script with an interpreter line naming a full path
[ -f make/data/blacklistedcertsconverter/blacklisted.certs.pem ] && sed -i 's|^#!.*|#! java BlacklistedCertsConverter SHA-256|' make/data/blacklistedcertsconverter/blacklisted.certs.pem
sed -i 's/__DATE__/""/; s/__TIME__/""/' src/hotspot/share/runtime/vm_version.cpp
# --disable-warnings-as-errors does not reach the jtreg native libraries
[ ! -f make/autoconf/generated-configure.sh ] || sed -i 's/-Werror//g' make/autoconf/generated-configure.sh
echo "10.46" > .src-rev

# GNU make 4.3+ evaluates `-include` in DependOnVariableHelper differently and the build stops at ..._the.BUILD_TOOLS_LANGTOOLS.vardeps
# (JDK-8237879); this is the upstream fix, present from JDK 15.
python3 - make/common/MakeBase.gmk <<'PPEOF'
import sys; p=sys.argv[1]; s=open(p).read()
old="        $(eval -include $(call DependOnVariableFileName, $1, $2)) \\\n"
new="        $(eval $1_filename := $(call DependOnVariableFileName, $1, $2)) \\\n        $(if $(wildcard $($1_filename)), $(eval include $($1_filename))) \\\n"
n=s.count(old); s=s.replace(old,new)
s=s.replace("$(call MakeDir, $(dir $(call DependOnVariableFileName, $1, $2)))","$(call MakeDir, $(dir $($1_filename)))")
s=s.replace("              $(call DependOnVariableFileName, $1, $2))) \\\n        $(call DependOnVariableFileName, $1, $2) \\\n","              $($1_filename))) \\\n        $($1_filename) \\\n")
open(p,'w').write(s); sys.exit(0 if n==1 else 1)
PPEOF
# hotspot takes gcc/g++ from PATH (hence CCDIR), the rest from CC/CXX
export JAVA_HOME="${BOOT}" PATH="${BOOT}/bin:${CCDIR}:${PATH}"
# JDK 10's AVX-512 intrinsics miscompile on AVX-512 hosts; every JVM of this build (the boot, the interim, the exploded image) runs with AVX2
export JAVA_TOOL_OPTIONS="-XX:UseAVX=2"
# --- configure + make ---
bash ./configure --with-boot-jdk="${BOOT}" --disable-option-checking --disable-warnings-as-errors --with-native-debug-symbols=none \
  "--with-extra-cflags=-fcommon -fno-delete-null-pointer-checks -fno-lifetime-dse -Wno-error=int-conversion" "--with-extra-cxxflags=-fcommon -fno-delete-null-pointer-checks -fno-lifetime-dse" --disable-hotspot-gtest --disable-freetype-bundling \
  --with-giflib=system --with-lcms=system --with-libjpeg=system --with-libpng=system --with-zlib=system \
  --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib > ../configure.log 2>&1 \
  || { grep -n -iE 'error|could not|cannot|not found' ../configure.log | tail -8 >&2 || true; echo "openjdk-10: configure failed" >&2; exit 1; }
make JOBS="${JOBS}" all > ../make.log 2>&1 \
  || { grep -nE 'error:|Error [0-9]|\*\*\* \[' ../make.log | grep -v Werror | tail -8 >&2 || true; tail -10 ../make.log >&2; echo "openjdk-10: make failed" >&2; exit 1; }
IMG="$(ls -d build/*/images/jdk | head -1)"
[ -x "${IMG}/bin/java" ] || { echo "openjdk-10: no jdk image" >&2; exit 1; }
mkdir -p "${DST}" && cp -a "${IMG}/." "${DST}/"
cd "${BUILDROOT}"
# --- P3 gate: the new javac compiles and the new VM runs a program of its own language level ---
mkdir -p gate; printf '%s\n' 'import java.util.*; import java.util.stream.*;' 'public class G { public static void main(String[] a){ List<Integer> xs = List.of(1,2,3,4,5,6); int s = xs.stream().takeWhile(x -> x <= 6).mapToInt(Integer::intValue).sum(); System.out.println("OJ:"+s+":"+Runtime.version().major()); } }' > gate/G.java
( cd gate && "${DST}/bin/javac" G.java )
OUT="$("${DST}/bin/java" -XX:UseAVX=2 -cp gate G 2>&1 | tail -1)"
[ "$OUT" = "OJ:21:10" ] || { echo "openjdk-10: gate printed '$OUT'" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}/usr/share/openjdk-10"
cat > "${OUTPUT_DIR}/usr/share/openjdk-10/BUILDINFO" <<EOF
openjdk-10
source: jdk-10+46.tar.gz + 12 patches\nboot: openjdk-9
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "openjdk-10: installed to ${PREFIX}"
