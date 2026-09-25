#!/bin/bash
# ecj-bootstrap-3.2.2: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# Eclipse ecj 3.2.2 compiled by jikes: the first Java-written Java compiler in the chain, shipped with a javac-compatible wrapper that runs it on jamvm-1.5.1.
set -eu
trap 'echo "ecj-bootstrap-3.2.2: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ecj-bootstrap-3.2.2"
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
[ "$(uname -m)" = x86_64 ] || { echo "ecj-bootstrap-3.2.2: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum python3 awk diff unzip zip; do
  command -v "$t" >/dev/null 2>&1 || { echo "ecj-bootstrap-3.2.2: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ecj-bootstrap-3.2.2: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ecj-bootstrap-3.2.2: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ecj-bootstrap-3.2.2: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/jikes-1.22/bin/jikes /usr/lib/jamvm-1.5.1/bin/jamvm /usr/lib/classpath-0.93/share/classpath/glibj.zip /usr/lib/ant-bootstrap-1.8.4/lib/ant.jar; do [ -e "$x" ] || { echo "ecj-bootstrap-3.2.2: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "ecj-bootstrap-3.2.2: libc.so fixup failed" >&2; exit 1; fi
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
[ -n "$(echo "${CXXINC}" | grep -o 'c++')" ] || { echo "ecj-bootstrap-3.2.2: cannot find g++'s libstdc++ include dirs" >&2; exit 1; }
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

# javac-compatible wrapper: ecj on jamvm. Arguments are rebuilt positionally so an empty `-bootclasspath ''`
# survives; defaults are only added for flags the caller did not pass.
mkjavac() {
cat > "$1" <<EOF
#!/bin/sh
vmargs=""; bcp=0; src=0; tgt=0; cp=0; n=\$#; i=0
while [ \$i -lt \$n ]; do a=\$1; shift; i=\$((i+1))
  case "\$a" in -J*) vmargs="\$vmargs \${a#-J}"; continue;; -bootclasspath) bcp=1;; -source) src=1;; -target) tgt=1;; -cp|-classpath) cp=1;; esac
  set -- "\$@" "\$a"
done
[ \$bcp = 1 ] || set -- -bootclasspath "$4" "\$@"; [ \$src = 1 ] || set -- -source $5 "\$@"; [ \$tgt = 1 ] || set -- -target $5 "\$@"; [ \$cp = 1 ] || set -- -cp . "\$@"
CLASSPATH="$3\${CLASSPATH:+:\$CLASSPATH}" exec $2 ${JVMFLAGS} \$vmargs org.eclipse.jdt.internal.compiler.batch.Main -nowarn "\$@"
EOF
chmod 0755 "$1"; }

JIKES=/usr/lib/jikes-1.22/bin/jikes; JAMVM=/usr/lib/jamvm-1.5.1/bin/jamvm
CP=/usr/lib/classpath-0.93/share/classpath; GLIBJ="${CP}/glibj.zip"; TOOLS="${CP}/tools.zip"
ANTJARS="$(ls /usr/lib/ant-bootstrap-1.8.4/lib/*.jar | tr '\n' ':')"
# --- P2 compile ecj with jikes ---
mkdir src && cd src && unzip -q ../ecjsrc-3.2.2.zip
export CLASSPATH="${GLIBJ}:${ANTJARS}"
find . -name '*.java' | sort > ../files.txt
"${JIKES}" -nowarn @../files.txt > ../jikes.log 2>&1 || { grep -m5 -iE 'error' ../jikes.log >&2; echo "ecj-bootstrap-3.2.2: jikes compile failed" >&2; exit 1; }
unset CLASSPATH
mkdir -p META-INF; printf 'Manifest-Version: 1.0\nMain-Class: org.eclipse.jdt.internal.compiler.batch.Main\n' > META-INF/MANIFEST.MF
find . -type f ! -name '*.java' | sort > ../pack.txt
mkdir -p "${DST}/share/java" "${DST}/bin"
# -X drops the extra fields, -0 stores; the member order is the sorted list
zip -q -0 -X "${DST}/share/java/ecj-bootstrap.jar" META-INF/MANIFEST.MF $(grep -v '^./META-INF/MANIFEST.MF$' ../pack.txt)
cd "${BUILDROOT}"
mkjavac "${DST}/bin/javac" "${JAMVM}" "${PREFIX}/share/java/ecj-bootstrap.jar" "${GLIBJ}:${TOOLS}" 1.5
# --- P3 gate: the wrapper compiles a class that jamvm runs ---
mkdir -p gate; printf 'public class W { public static void main(String[] a){ System.out.println("ECJ322:"+(6*7)); } }\n' > gate/W.java
( cd gate && CLASSPATH="${DST}/share/java/ecj-bootstrap.jar" "${JAMVM}" ${JVMFLAGS} org.eclipse.jdt.internal.compiler.batch.Main -nowarn -bootclasspath "${GLIBJ}:${TOOLS}" -source 1.5 -target 1.5 -cp . W.java ) > gate/compile.log 2>&1 || { cat gate/compile.log >&2; echo "ecj-bootstrap-3.2.2: ecj cannot compile" >&2; exit 1; }
OUT="$("${JAMVM}" ${JVMFLAGS} -cp gate W 2>&1 | tail -1)"
[ "$OUT" = "ECJ322:42" ] || { echo "ecj-bootstrap-3.2.2: gate printed '$OUT'" >&2; exit 1; }

# --- P4 deterministic archives: zip entry timestamps and order are build-time noise ---
python3 - "${DST}" <<'PYEOF'
import io, os, shutil, sys, zipfile
def norm_bytes(b):
    """Rewrite a zip: fixed entry timestamps, sorted entries (manifest first), nested jars normalised too."""
    with zipfile.ZipFile(io.BytesIO(b)) as z:
        infos = z.infolist(); data = {i.filename: z.read(i) for i in infos}
    order = sorted(infos, key=lambda i: (0 if i.filename == 'META-INF/MANIFEST.MF' else 1 if i.filename.startswith('META-INF/') else 2, i.filename))
    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w') as o:
        for i in order:
            d = data[i.filename]
            if (i.filename.endswith(('.jar', '.zip')) or i.filename.endswith('ct.sym')) and zipfile.is_zipfile(io.BytesIO(d)): d = norm_bytes(d)
            zi = zipfile.ZipInfo(i.filename, date_time=(1980, 1, 1, 0, 0, 0))
            zi.compress_type = i.compress_type; zi.external_attr = i.external_attr; zi.create_system = 3
            o.writestr(zi, d)
    return out.getvalue()
root = sys.argv[1]; n = 0
for dp, _, fn in os.walk(root):
    for f in fn:
        p = os.path.join(dp, f)
        if os.path.islink(p) or not (f.endswith(('.jar', '.zip', '.war', '.jmod')) or f == 'ct.sym'): continue
        with open(p, 'rb') as fh: raw = fh.read()
        head = b''
        if f.endswith('.jmod'):   # a jmod is a zip behind a 4-byte "JM" magic
            if raw[:2] != b'JM': continue
            head, raw = raw[:4], raw[4:]
        if not zipfile.is_zipfile(io.BytesIO(raw)): continue
        tmp = p + '.tmp'
        with open(tmp, 'wb') as out: out.write(head); out.write(norm_bytes(raw))
        shutil.copymode(p, tmp); os.replace(tmp, p); n += 1
print("normalised", n, "archives")
PYEOF
# class-data-sharing archives are dumped at build time from a live VM and do not reproduce; the VM runs without them
find "${DST}" -name 'classes*.jsa' -type f -delete
# src.zip carries generated sources that do not reproduce; a bootstrap JDK does not need it
find "${DST}" -name 'src.zip' -type f -delete
# the default class list is written in class-load order, which varies run to run; only its membership matters
[ ! -f "${DST}/lib/classlist" ] || { LC_ALL=C sort "${DST}/lib/classlist" > "${DST}/lib/classlist.sorted" && mv "${DST}/lib/classlist.sorted" "${DST}/lib/classlist"; }

mkdir -p "${OUTPUT_DIR}/usr/share/ecj-bootstrap-3.2.2"
cat > "${OUTPUT_DIR}/usr/share/ecj-bootstrap-3.2.2/BUILDINFO" <<EOF
ecj-bootstrap-3.2.2
source: ecjsrc-3.2.2.zip
compiler: jikes-1.22; wrapper runs ecj on jamvm-1.5.1 against classpath-0.93
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "ecj-bootstrap-3.2.2: installed to ${PREFIX}"
