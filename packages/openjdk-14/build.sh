#!/bin/bash
# openjdk-14: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# OpenJDK 14.0.2 from the GitHub tag archive, built with ../openjdk-13 as the boot JDK.
set -eu
trap 'echo "openjdk-14: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/openjdk-14"
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
[ "$(uname -m)" = x86_64 ] || { echo "openjdk-14: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum python3 gzip gawk patch zip unzip cpio file which pkg-config objcopy readelf autoconf; do
  command -v "$t" >/dev/null 2>&1 || { echo "openjdk-14: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "openjdk-14: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "openjdk-14: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "openjdk-14: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/openjdk-13/bin/javac /usr/lib/openjdk-13/bin/java /usr/include/gif_lib.h /usr/include/freetype2/freetype/freetype.h /usr/include/X11/Intrinsic.h; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "openjdk-14: libc.so fixup failed" >&2; exit 1; fi
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"
INC="-isystem ${SR}/include -isystem /usr/include"
# C++: rebuild g++'s own include chain (libstdc++, gcc freestanding) ahead of the sysroot's glibc headers, and
# /usr/include last. Hoisting a glibc dir above libstdc++ shadows its <math.h> wrapper (no float overloads) and
# a hoisted /usr/include empties the tail #include_next needs.
CXXINC=""; CXXTAIL=""
for d in $("${BGXX}" -E -x c++ -v /dev/null 2>&1 | sed -n '/#include <...> search starts here:/,/End of search list./p' | sed '1d;$d'); do
  case "$d" in */c++/*) CXXINC="${CXXINC} -isystem $d" ;; /usr/include|/usr/local/include) ;; /usr/include/*) CXXTAIL="${CXXTAIL} -idirafter $d" ;; *) CXXINC="${CXXINC} -isystem $d" ;; esac
done
CXXINC="${CXXINC# } -isystem ${SR}/include${CXXTAIL} -idirafter /usr/include"
[ -n "$(echo "${CXXINC}" | grep -o 'c++')" ] || { echo "openjdk-14: cannot find g++'s libstdc++ include dirs" >&2; exit 1; }
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
cat > "${CCDIR}/gcc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGCC}" ${INC}  "\$@" ;; esac; done
exec "${BGCC}" ${INC}  "\$@" ${LNK}
WRAP
cat > "${CCDIR}/g++" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGXX}" -nostdinc -nostdinc++ ${CXXINC} "\$@" ;; esac; done
exec "${BGXX}" -nostdinc -nostdinc++ ${CXXINC} "\$@" ${LNK}
WRAP
chmod 0755 "${CCDIR}/gcc" "${CCDIR}/g++"
export CC="${CCDIR}/gcc" CXX="${CCDIR}/g++"

BOOT=/usr/lib/openjdk-13
# --- P2 unpack (the GitHub tag archive; shipped binaries and jars removed, as Guix does) ---
mkdir src && tar -xzf jdk-14.0.2-ga.tar.gz -C src --strip-components=1
cd src
find . -type f \( -name '*.bin' -o -name '*.exe' -o -name '*.jar' \) -delete
patch -p1 < ../openjdk-10-setsignalhandler.patch
patch -p1 < ../openjdk-10-jtask-reproducibility.patch
patch -p1 < ../openjdk-13-classlist-reproducibility.patch
# --- source fixes ---
# the certificate converter is run as a script with an interpreter line naming a full path
[ -f make/data/blacklistedcertsconverter/blacklisted.certs.pem ] && sed -i 's|^#!.*|#! java BlacklistedCertsConverter SHA-256|' make/data/blacklistedcertsconverter/blacklisted.certs.pem
sed -i 's/__DATE__/""/; s/__TIME__/""/' src/hotspot/share/runtime/abstract_vm_version.cpp
# --disable-warnings-as-errors does not reach the jtreg native libraries
[ ! -f make/autoconf/generated-configure.sh ] || sed -i 's/-Werror//g' make/autoconf/generated-configure.sh
echo "14.0.2" > .src-rev

# GNU make 4.3+ evaluates `-include` in DependOnVariableHelper differently and the build stops at ..._the.BUILD_TOOLS_LANGTOOLS.vardeps
# (JDK-8237879); this is the upstream fix, present from JDK 15 and in some later update releases.
python3 - make/common/MakeBase.gmk <<'PPEOF'
import sys; p=sys.argv[1]; s=open(p).read()
old="        $(eval -include $(call DependOnVariableFileName, $1, $2)) \\\n"
new="        $(eval $1_filename := $(call DependOnVariableFileName, $1, $2)) \\\n        $(if $(wildcard $($1_filename)), $(eval include $($1_filename))) \\\n"
n=s.count(old); s=s.replace(old,new)
s=s.replace("$(call MakeDir, $(dir $(call DependOnVariableFileName, $1, $2)))","$(call MakeDir, $(dir $($1_filename)))")
s=s.replace("              $(call DependOnVariableFileName, $1, $2))) \\\n        $(call DependOnVariableFileName, $1, $2) \\\n","              $($1_filename))) \\\n        $($1_filename) \\\n")
open(p,'w').write(s); sys.exit(0 if n==1 or '$1_filename :=' in s else 1)   # update releases may carry the fix already
PPEOF
# hotspot takes gcc/g++ from PATH (hence CCDIR), the rest from CC/CXX
export JAVA_HOME="${BOOT}" PATH="${BOOT}/bin:${CCDIR}:${PATH}"
export SOURCE_DATE_EPOCH=1   # JDK 13+ configure takes the source date from it
# --- configure + make ---
bash ./configure --with-boot-jdk="${BOOT}" --disable-option-checking --disable-warnings-as-errors --with-native-debug-symbols=none \
  "--with-extra-cflags=-fcommon -fno-delete-null-pointer-checks -fno-lifetime-dse -Wno-error=int-conversion" --disable-hotspot-gtest --with-version-pre= --with-hotspot-build-time=1970-01-01T00:00:01 --enable-reproducible-build \
  --with-giflib=system --with-lcms=system --with-libjpeg=system --with-libpng=system --with-zlib=system \
  --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib > ../configure.log 2>&1 \
  || { grep -n -iE 'error|could not|cannot|not found' ../configure.log | tail -8 >&2 || true; echo "openjdk-14: configure failed" >&2; exit 1; }
make JOBS="${JOBS}" all > ../make.log 2>&1 \
  || { grep -nE 'error:|Error [0-9]|\*\*\* \[' ../make.log | grep -v Werror | tail -8 >&2 || true; tail -10 ../make.log >&2; echo "openjdk-14: make failed" >&2; exit 1; }
IMG="$(ls -d build/*/images/jdk | head -1)"
[ -x "${IMG}/bin/java" ] || { echo "openjdk-14: no jdk image" >&2; exit 1; }
mkdir -p "${DST}" && cp -a "${IMG}/." "${DST}/"
cd "${BUILDROOT}"
# --- P3 gate: the new javac compiles and the new VM runs a program of its own language level ---
mkdir -p gate; printf '%s\n' 'import java.util.*;' 'public class G { public static void main(String[] a){ var xs = List.of(1,2,3,4,5,6); var s = 0; for (var x : xs) s += x; System.out.println("OJ:"+s+":"+Runtime.version().feature()+":"+"ab".repeat(2)); } }' > gate/G.java
( cd gate && "${DST}/bin/javac" G.java )
OUT="$("${DST}/bin/java" -cp gate G 2>&1 | tail -1)"
[ "$OUT" = "OJ:21:14:abab" ] || { echo "openjdk-14: gate printed '$OUT'" >&2; exit 1; }

# --- P4 deterministic archives: zip entry timestamps and order are build-time noise ---
python3 - "${DST}" <<'PYEOF'
import os, shutil, sys, zipfile
root = sys.argv[1]; n = 0
for dp, _, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        if os.path.islink(p) or not (f.endswith(('.jar', '.zip', '.war')) or f == 'ct.sym') or not zipfile.is_zipfile(p): continue
        with zipfile.ZipFile(p) as z:
            infos = z.infolist(); data = {i.filename: z.read(i) for i in infos}
        # the manifest stays first: JarInputStream only sees it there
        order = sorted(infos, key=lambda i: (0 if i.filename == 'META-INF/MANIFEST.MF' else 1 if i.filename.startswith('META-INF/') else 2, i.filename))
        tmp = p + '.tmp'
        with zipfile.ZipFile(tmp, 'w') as out:
            for i in order:
                zi = zipfile.ZipInfo(i.filename, date_time=(1980, 1, 1, 0, 0, 0))
                zi.compress_type = i.compress_type; zi.external_attr = i.external_attr; zi.create_system = 3
                out.writestr(zi, data[i.filename])
        shutil.copymode(p, tmp); os.replace(tmp, p); n += 1
print("normalised", n, "archives")
PYEOF

mkdir -p "${OUTPUT_DIR}/usr/share/openjdk-14"
cat > "${OUTPUT_DIR}/usr/share/openjdk-14/BUILDINFO" <<EOF
openjdk-14
source: jdk-14.0.2-ga.tar.gz + 3 patches\nboot: openjdk-13
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "openjdk-14: installed to ${PREFIX}"
