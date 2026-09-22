#!/bin/bash
# classpath-0.99: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# GNU Classpath 0.99 compiled by ecj-bootstrap-3.2.2 (on jamvm-1.5.1); ships its tools with jamvm-run wrappers.
set -eu
trap 'echo "classpath-0.99: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/classpath-0.99"
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
[ "$(uname -m)" = x86_64 ] || { echo "classpath-0.99: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum python3 fastjar zip; do
  command -v "$t" >/dev/null 2>&1 || { echo "classpath-0.99: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "classpath-0.99: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "classpath-0.99: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "classpath-0.99: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/ecj-bootstrap-3.2.2/bin/javac /usr/lib/jamvm-1.5.1/bin/jamvm; do [ -e "$x" ] || { echo "classpath-0.99: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "classpath-0.99: libc.so fixup failed" >&2; exit 1; fi
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
[ -n "$(echo "${CXXINC}" | grep -o 'c++')" ] || { echo "classpath-0.99: cannot find g++'s libstdc++ include dirs" >&2; exit 1; }
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
cat > "${CCDIR}/gcc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGCC}" ${INC} -std=gnu17 -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=int-conversion "\$@" ;; esac; done
exec "${BGCC}" ${INC} -std=gnu17 -Wno-error=implicit-function-declaration -Wno-error=incompatible-pointer-types -Wno-error=int-conversion "\$@" ${LNK}
WRAP
cat > "${CCDIR}/g++" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E|-M|-MM) exec "${BGXX}" -nostdinc -nostdinc++ ${CXXINC} "\$@" ;; esac; done
exec "${BGXX}" -nostdinc -nostdinc++ ${CXXINC} "\$@" ${LNK}
WRAP
chmod 0755 "${CCDIR}/gcc" "${CCDIR}/g++"
export CC="${CCDIR}/gcc" CXX="${CCDIR}/g++"

JAVAC=/usr/lib/ecj-bootstrap-3.2.2/bin/javac; ECJJAR=/usr/lib/ecj-bootstrap-3.2.2/share/java/ecj-bootstrap.jar; JAMVM=/usr/lib/jamvm-1.5.1/bin/jamvm
# --- P2 build ---
mkdir src && tar -xzf classpath-0.99.tar.gz -C src --strip-components=1
cd src
./configure --prefix="${PREFIX}" --with-ecj-jar="${ECJJAR}" JAVAC="${JAVAC}" JAVA="${JAMVM}" GCJ_JAVAC_TRUE=no ac_cv_prog_java_works=yes \
  --disable-Werror --disable-gmp --disable-gtk-peer --disable-gconf-peer --disable-plugin --disable-dssi --disable-alsa --disable-gjdoc > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "classpath-0.99: configure failed" >&2; exit 1; }
make -j"${JOBS}" > ../make.log 2>&1 || { grep -A5 -m5 'ERROR in' ../make.log >&2 || true; grep -n -m5 -iE ' error|Error [0-9]' ../make.log >&2 || true; echo "classpath-0.99: make failed" >&2; exit 1; }
make install DESTDIR="${OUTPUT_DIR}" > ../install.log 2>&1 && make install-data DESTDIR="${OUTPUT_DIR}" >> ../install.log 2>&1 \
  || { tail -20 ../install.log >&2; echo "classpath-0.99: install failed" >&2; exit 1; }
cd "${BUILDROOT}"
# the tools (javah, rmic, ...) ship only as tools.zip: jamvm-run wrappers the next rungs' configures find on PATH
mkdir -p "${DST}/bin"
for tool in javah rmic rmid orbd rmiregistry native2ascii; do M=Main; [ $tool = native2ascii ] && M=Native2ASCII
  printf '#!/bin/sh\nexec %s %s -classpath %s/share/classpath/tools.zip gnu.classpath.tools.%s.%s "$@"\n' "${JAMVM}" "${JVMFLAGS}" "${PREFIX}" $tool $M > "${DST}/bin/$tool"; chmod 0755 "${DST}/bin/$tool"; done
# --- P3 gate ---
[ -s "${DST}/share/classpath/glibj.zip" ] && [ -s "${DST}/share/classpath/tools.zip" ] || { echo "classpath-0.99: glibj.zip/tools.zip missing" >&2; exit 1; }

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

mkdir -p "${OUTPUT_DIR}/usr/share/classpath-0.99"
cat > "${OUTPUT_DIR}/usr/share/classpath-0.99/BUILDINFO" <<EOF
classpath-0.99
source: classpath-0.99.tar.gz
javac: ecj-bootstrap-3.2.2 on jamvm-1.5.1
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "classpath-0.99: installed to ${PREFIX}"
