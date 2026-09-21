#!/bin/bash
# classpath-devel: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# GNU Classpath from git (e7c13ee0, Java 6 library support) compiled by ecj-bootstrap-3.2.2; @Override annotations stripped for that compiler.
set -eu
trap 'echo "classpath-devel: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/classpath-devel"
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
[ "$(uname -m)" = x86_64 ] || { echo "classpath-devel: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum fastjar zip autoreconf; do
  command -v "$t" >/dev/null 2>&1 || { echo "classpath-devel: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "classpath-devel: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "classpath-devel: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "classpath-devel: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/ecj-bootstrap-3.2.2/bin/javac /usr/lib/jamvm-1.5.1/bin/jamvm /usr/lib/classpath-0.99/bin/javah; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "classpath-devel: libc.so fixup failed" >&2; exit 1; fi
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
[ -n "$(echo "${CXXINC}" | grep -o 'c++')" ] || { echo "classpath-devel: cannot find g++'s libstdc++ include dirs" >&2; exit 1; }
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
mkdir src && tar -xzf classpath-devel-e7c13ee0-src2.tar.gz -C src --strip-components=1
cd src
# ecj 3.2.2 predates @Override on interface methods
find java -name '*.java' -exec sed -i 's/@Override//' {} +
autoreconf -vif > ../autoreconf.log 2>&1 || { tail -20 ../autoreconf.log >&2; echo "classpath-devel: autoreconf failed" >&2; exit 1; }
# configure ignores --with-javac and probes PATH for ecj/javac; the tool wrappers live on PATH for configure and make
export PATH="/usr/lib/ecj-bootstrap-3.2.2/bin:/usr/lib/classpath-0.99/bin:${PATH}"
./configure --prefix="${PREFIX}" --with-ecj-jar="${ECJJAR}" --with-javac="${JAVAC}" JAVA="${JAMVM}" GCJ_JAVAC_TRUE=no ac_cv_prog_java_works=yes \
  --disable-Werror --disable-gmp --disable-gtk-peer --disable-gconf-peer --disable-plugin --disable-dssi --disable-alsa --disable-gjdoc > ../configure.log 2>&1 \
  || { tail -30 ../configure.log >&2; echo "classpath-devel: configure failed" >&2; exit 1; }
# MAKEINFO=true: the git snapshot ships no prebuilt .info files and texinfo is not in the closure
make -j"${JOBS}" JAVAC_MEM_OPT="-J-Xms512M -J-Xmx768M" MAKEINFO=true > ../make.log 2>&1 || { grep -A5 -m5 'ERROR in' ../make.log >&2 || true; grep -n -m5 -iE ' error|Error [0-9]' ../make.log >&2 || true; echo "classpath-devel: make failed" >&2; exit 1; }
make install MAKEINFO=true DESTDIR="${OUTPUT_DIR}" > ../install.log 2>&1 && make install-data MAKEINFO=true DESTDIR="${OUTPUT_DIR}" >> ../install.log 2>&1 \
  || { tail -20 ../install.log >&2; echo "classpath-devel: install failed" >&2; exit 1; }
cd "${BUILDROOT}"
mkdir -p "${DST}/bin"
for tool in javah rmic rmid orbd rmiregistry native2ascii gjdoc; do M=Main; [ $tool = native2ascii ] && M=Native2ASCII
  printf '#!/bin/sh\nexec %s %s -classpath %s/share/classpath/tools.zip gnu.classpath.tools.%s.%s "$@"\n' "${JAMVM}" "${JVMFLAGS}" "${PREFIX}" $tool $M > "${DST}/bin/$tool"; chmod 0755 "${DST}/bin/$tool"; done
# --- P3 gate ---
[ -s "${DST}/share/classpath/glibj.zip" ] && [ -s "${DST}/share/classpath/tools.zip" ] || { echo "classpath-devel: glibj.zip/tools.zip missing" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}/usr/share/classpath-devel"
cat > "${OUTPUT_DIR}/usr/share/classpath-devel/BUILDINFO" <<EOF
classpath-devel
source: classpath-devel-e7c13ee0-src2.tar.gz (git e7c13ee0)
javac: ecj-bootstrap-3.2.2 on jamvm-1.5.1
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "classpath-devel: installed to ${PREFIX}"
