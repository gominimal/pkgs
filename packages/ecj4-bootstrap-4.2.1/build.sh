#!/bin/bash
# ecj4-bootstrap-4.2.1: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 .. 25).
# Eclipse ecj 4.2.1 (Java 7 language) compiled by ecj 3.2.2 on jamvm-2.0.0 against classpath-devel; ships a javac wrapper (jamvm-2.0.0, -source 1.7).
set -eu
trap 'echo "ecj4-bootstrap-4.2.1: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/ecj4-bootstrap-4.2.1"
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
[ "$(uname -m)" = x86_64 ] || { echo "ecj4-bootstrap-4.2.1: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum unzip zip; do
  command -v "$t" >/dev/null 2>&1 || { echo "ecj4-bootstrap-4.2.1: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "ecj4-bootstrap-4.2.1: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "ecj4-bootstrap-4.2.1: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "ecj4-bootstrap-4.2.1: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/jamvm-2.0.0/bin/jamvm /usr/lib/ecj-bootstrap-3.2.2/share/java/ecj-bootstrap.jar /usr/lib/classpath-devel/share/classpath/glibj.zip /usr/lib/ant-bootstrap-1.8.4/lib/ant.jar; do [ -e "$x" ] || { echo "@NAME@: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "ecj4-bootstrap-4.2.1: libc.so fixup failed" >&2; exit 1; fi
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

JAMVM2=/usr/lib/jamvm-2.0.0/bin/jamvm; ECJ3=/usr/lib/ecj-bootstrap-3.2.2/share/java/ecj-bootstrap.jar
CPD=/usr/lib/classpath-devel/share/classpath; BCP="${CPD}/glibj.zip:${CPD}/tools.zip"
ANTJARS="$(ls /usr/lib/ant-bootstrap-1.8.4/lib/*.jar | tr '\n' ':')"
# ecj 3.2.2 running on jamvm-2.0.0 against classpath-devel: the compiler for this rung
mkjavac "${BUILDROOT}/javac3" "${JAMVM2}" "${ECJ3}" "${BCP}" 1.5
# --- P2 compile ---
mkdir src && cd src && unzip -q ../ecjsrc-4.2.1.jar
rm -f org/eclipse/jdt/core/JDTCompilerAdapter.java; rm -rf org/eclipse/jdt/internal/antadapter   # ant adapter: not built here
find . -name '*.java' -exec sed -i 's/@Override//' {} +
export CLASSPATH="${CPD}/glibj.zip:${ANTJARS}"
find . -name '*.java' | sort > ../files.txt
"${BUILDROOT}/javac3" -J-Xmx1500M @../files.txt > ../ecj.log 2>&1 || { grep -m5 -iE 'error' ../ecj.log >&2; echo "ecj4-bootstrap-4.2.1: compile failed" >&2; exit 1; }
unset CLASSPATH
mkdir -p META-INF; printf 'Manifest-Version: 1.0\nMain-Class: org.eclipse.jdt.internal.compiler.batch.Main\n' > META-INF/MANIFEST.MF
find . -type f ! -name '*.java' | sort > ../pack.txt
mkdir -p "${DST}/share/java" "${DST}/bin"
zip -q -0 -X "${DST}/share/java/ecj-bootstrap.jar" META-INF/MANIFEST.MF $(grep -v '^./META-INF/MANIFEST.MF$' ../pack.txt)
cd "${BUILDROOT}"
mkjavac "${DST}/bin/javac" "${JAMVM2}" "${PREFIX}/share/java/ecj-bootstrap.jar" "${BCP}" 1.7
# --- P3 gate: Java 7 source (diamond, string switch) compiled by ecj 4.2.1, run on jamvm-2.0.0 ---
mkdir -p gate; printf 'import java.util.*; public class G7 { public static void main(String[] a){ List<Integer> l = new ArrayList<>(); for (int i=1;i<=6;i++) l.add(i); int s=0; for (int x : l) s+=x; String v = "diamond"; switch (v) { case "diamond": System.out.println("ECJ4:"+s); break; default: System.out.println("ECJ4:bad"); } } }\n' > gate/G7.java
( cd gate && CLASSPATH="${DST}/share/java/ecj-bootstrap.jar" "${JAMVM2}" ${JVMFLAGS} org.eclipse.jdt.internal.compiler.batch.Main -nowarn -bootclasspath "${BCP}" -source 1.7 -target 1.7 -cp . G7.java ) > gate/compile.log 2>&1 || { cat gate/compile.log >&2; echo "ecj4-bootstrap-4.2.1: gate compile failed" >&2; exit 1; }
OUT="$("${JAMVM2}" ${JVMFLAGS} -cp gate G7 2>&1 | tail -1)"
[ "$OUT" = "ECJ4:21" ] || { echo "ecj4-bootstrap-4.2.1: gate printed '$OUT'" >&2; exit 1; }

mkdir -p "${OUTPUT_DIR}/usr/share/ecj4-bootstrap-4.2.1"
cat > "${OUTPUT_DIR}/usr/share/ecj4-bootstrap-4.2.1/BUILDINFO" <<EOF
ecj4-bootstrap-4.2.1
source: ecjsrc-4.2.1.jar
compiler: ecj-bootstrap-3.2.2 on jamvm-2.0.0 against classpath-devel
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "ecj4-bootstrap-4.2.1: installed to ${PREFIX}"
