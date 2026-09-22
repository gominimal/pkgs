#!/bin/bash
# icedtea-7: one rung of the JVM ladder (jikes-1.22 -> classpath-0.93 -> jamvm-1.5.1 -> ant-bootstrap-1.8.4 -> ecj-bootstrap-3.2.2 -> classpath-0.99 -> classpath-devel -> jamvm-2.0.0 -> ecj4-bootstrap-4.2.1 -> icedtea-7 -> icedtea-8 -> openjdk-9 -> ... -> openjdk-25).
# OpenJDK 7u171 via the IcedTea 2.6.13 harness in --enable-bootstrap mode: ecj4-bootstrap-4.2.1 on jamvm-2.0.0 with classpath-devel as the "boot JDK" builds an interim JDK, which then builds the real one.
set -eu
trap 'echo "icedtea-7: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/icedtea-7"
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
[ "$(uname -m)" = x86_64 ] || { echo "icedtea-7: amd64 ladder rung on $(uname -m)" >&2; exit 1; }
for t in gcc g++ ld ar ranlib make sed grep tar find xargs sha256sum python3 awk diff gawk xz bzip2 gzip patch zip unzip cpio file which pkg-config xsltproc objcopy; do
  command -v "$t" >/dev/null 2>&1 || { echo "icedtea-7: '$t' not on PATH" >&2; exit 1; }
done
BGCC="$(command -v gcc)"; BGXX="$(command -v g++)"
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "icedtea-7: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}'" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "icedtea-7: glibc sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "icedtea-7: glibc loader missing at ${LOADER}" >&2; exit 1; }
for x in /usr/lib/jamvm-2.0.0/bin/jamvm /usr/lib/classpath-devel/share/classpath/glibj.zip /usr/lib/classpath-devel/share/classpath/tools.zip /usr/lib/classpath-devel/bin/javah /usr/lib/classpath-devel/bin/rmic /usr/lib/ecj4-bootstrap-4.2.1/bin/javac /usr/lib/ant-bootstrap-1.8.4/bin/ant /usr/include/freetype2/freetype/freetype.h /usr/include/X11/Intrinsic.h; do [ -e "$x" ] || { echo "icedtea-7: missing boot artifact $x" >&2; exit 1; }; done

# --- P1 sysroot C/C++ wrappers ---
# The sysroot's libc.so is a linker script with staging paths; regenerate it.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "icedtea-7: libc.so fixup failed" >&2; exit 1; fi
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
[ -n "$(echo "${CXXINC}" | grep -o 'c++')" ] || { echo "icedtea-7: cannot find g++'s libstdc++ include dirs" >&2; exit 1; }
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

JV2=/usr/lib/jamvm-2.0.0/bin/jamvm; CPD=/usr/lib/classpath-devel; JAVAC4=/usr/lib/ecj4-bootstrap-4.2.1/bin/javac; ANT=/usr/lib/ant-bootstrap-1.8.4
TOOLSZIP="${CPD}/share/classpath/tools.zip"; GLIBJ="${CPD}/share/classpath/glibj.zip"
# --- P2 unpack: the harness, then the seven drops where its configure expects them ---
mkdir src && tar -xJf icedtea-2.6.13.tar.xz -C src --strip-components=1
cd src
mkdir openjdk.src && tar -xjf ../icedtea7-2.6.13-openjdk.tar.bz2 -C openjdk.src --strip-components=1
for d in corba jaxp jaxws jdk langtools hotspot; do mkdir -p "openjdk.src/$d" && tar -xjf "../icedtea7-2.6.13-$d.tar.bz2" -C "openjdk.src/$d" --strip-components=1; done
( cd openjdk.src/jdk && patch -p1 < ../../../jdk-currency-time-bomb.patch )
( cd openjdk.src/hotspot && patch -p1 < ../../../icedtea-7-hotspot-pointer-comparison.patch )
sed -i 's/__DATE__/""/; s/__TIME__/""/' openjdk.src/hotspot/src/share/vm/runtime/vm_version.cpp   # the VM banner's build date
# --- source fixes ---
sed -i 's|DISTRIBUTION_ID="\$(DIST_ID)"|DISTRIBUTION_ID="\\"minimal\\""|' Makefile.in
sed -i -E 's/^(\s*)DIST_ID=".*$/\1DIST_ID="minimal"/; s/^(\s*)DIST_NAME=".*$/\1DIST_NAME="minimal"/' configure
# the boot JDK is GNU Classpath: its class library is glibj.zip, not jre/lib/rt.jar
sed -i "s|\$(SYSTEM_JDK_DIR)/jre/lib/rt.jar|${GLIBJ}|g" Makefile.in
# the freetype sanity check compares version strings with strcmp ("2.14.3" < "2.2.1"); require the installed one
FTV="$(awk '/#define FREETYPE_MAJOR/{a=$3} /#define FREETYPE_MINOR/{b=$3} /#define FREETYPE_PATCH/{c=$3} END{print a"."b"."c}' /usr/include/freetype2/freetype/freetype.h)"
case "$FTV" in [0-9]*.[0-9]*.[0-9]*) ;; *) echo "icedtea-7: cannot read the freetype version ('$FTV')" >&2; exit 1 ;; esac
sed -i "s/REQUIRED_FREETYPE_VERSION = 2.2.1/REQUIRED_FREETYPE_VERSION = ${FTV}/" patches/boot/revert-6973616.patch openjdk.src/jdk/make/common/shared/Defs-versions.gmk
sed -i 's|attr/xattr.h|sys/xattr.h|' configure openjdk.src/jdk/src/solaris/native/sun/nio/fs/LinuxNativeDispatcher.c
# C of 2011 under a C23-default gcc
sed -i 's|^CFLAGS_COMMON   = -fno-strict-aliasing.*|& -fcommon -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=incompatible-pointer-types -Wno-error=int-conversion|' openjdk.src/jdk/make/common/Defs-linux.gmk
sed -i 's|#include <sys/sysctl.h>|#include <linux/sysctl.h>|' openjdk.src/jdk/src/solaris/native/java/net/PlainSocketImpl.c openjdk.src/jdk/src/solaris/native/java/net/PlainDatagramSocketImpl.c
sed -i 's|\$(LDD) \$1 &&||' openjdk.src/jdk/make/common/shared/Defs-linux.gmk
# dump.o miscompiles at -O2 with current gcc
sed -i 's|^OPT_CFLAGS/NOOPT.*|&\nOPT_CFLAGS/dump.o += -O0|' openjdk.src/hotspot/make/linux/makefiles/gcc.make
sed -i 's|/bin/sh|/bin/bash|' openjdk.src/hotspot/make/linux/makefiles/buildtree.make
# currency transitions in the past confuse GenerateCurrencyData
sed -i 's/AZ=AZM;2005-12-31-20-00-00;AZN/AZ=AZN/; s/MZ=MZM;2006-06-30-22-00-00;MZN/MZ=MZN/; s/RO=ROL;2005-06-30-21-00-00;RON/RO=RON/; s/TR=TRL;2004-12-31-22-00-00;TRY/TR=TRY/' openjdk.src/jdk/src/share/classes/java/util/CurrencyData.properties
grep -q 'glibj.zip' Makefile.in && grep -q "FREETYPE_VERSION = ${FTV}" openjdk.src/jdk/make/common/shared/Defs-versions.gmk \
  && grep -q fcommon openjdk.src/jdk/make/common/Defs-linux.gmk && grep -q 'dump.o += -O0' openjdk.src/hotspot/make/linux/makefiles/gcc.make \
  || { echo "icedtea-7: a source fix did not apply" >&2; exit 1; }
# --- the boot JDK as configure and the OpenJDK makefiles expect it: java, javac, jar ---
# The build passes its own heap flags (-J-Xmx512m); ecj needs far more on the jdk class list, so the shims drop them and impose a large heap.
SHIM="${BUILDROOT}/jdk-shim/bin"; mkdir -p "${SHIM}"
cat > "${SHIM}/java" <<WRAP
#!/bin/sh
for a in "\$@"; do shift; case "\$a" in -Xmx*|-Xms*|-XX:*) ;; *) set -- "\$@" "\$a";; esac; done
exec ${JV2} ${JVMFLAGS} -Xmx8g -Xms1g "\$@"
WRAP
cat > "${SHIM}/javac" <<WRAP
#!/bin/sh
for a in "\$@"; do shift; case "\$a" in -J-Xmx*|-J-Xms*|-J-XX:*) ;; *) set -- "\$@" "\$a";; esac; done
exec ${JAVAC4} -J-Xmx12g -J-Xms2g -J-Xss8m "\$@"
WRAP
cat > "${SHIM}/jar" <<WRAP
#!/bin/sh
exec ${JV2} ${JVMFLAGS} -Xmx4g -classpath ${TOOLSZIP} gnu.classpath.tools.jar.Main "\$@"
WRAP
chmod 0755 "${SHIM}"/*
export ANT_OPTS="-Xmx8g -Xms1g" JAVAC_MEM_OPT="-J-Xmx12g -J-Xms2g"
export PATH="${SHIM}:${ANT}/bin:${CCDIR}:${PATH}" ANT_HOME="${ANT}" JAVACMD="${SHIM}/java"
export CLASSPATH="${GLIBJ}:${TOOLSZIP}" JAVACFLAGS="-cp ${GLIBJ}:${TOOLSZIP}"
# the jdk makefiles take the C toolchain from ALT_COMPILER_PATH, hotspot's take gcc/g++ from PATH (hence CCDIR on PATH)
export ALT_COMPILER_PATH="${CCDIR}" ALT_OBJCOPY="$(command -v objcopy)" ALT_CUPS_HEADERS_PATH=/usr/include \
  ALT_FREETYPE_HEADERS_PATH=/usr/include/freetype2 ALT_FREETYPE_LIB_PATH=/usr/lib DISABLE_HOTSPOT_OS_VERSION_CHECK=ok
# --- configure + make ---
./configure --enable-bootstrap --disable-downloading --disable-tests --disable-docs --without-rhino --disable-nss \
  --disable-system-sctp --disable-system-pcsc --disable-system-kerberos --disable-system-gtk --disable-system-gio --disable-system-gconf \
  --disable-system-gif --disable-system-jpeg --disable-system-png --enable-system-zlib --enable-system-lcms --enable-system-cups --enable-system-fontconfig \
  --with-parallel-jobs="${JOBS}" --with-openjdk-src-dir=./openjdk.src --with-ecj="${SHIM}/javac" --with-jdk-home="${CPD}" --with-java="${JV2}" \
  --with-jar="${SHIM}/jar" --with-javah="${CPD}/bin/javah" --with-rmic="${CPD}/bin/rmic" --with-ant-home="${ANT}" > ../configure.log 2>&1 \
  || { grep -n -iE 'error|cannot|not found|no acceptable' ../configure.log | tail -8 >&2 || true; tail -10 ../configure.log >&2; echo "icedtea-7: configure failed" >&2; exit 1; }
make -j"${JOBS}" > ../make.log 2>&1 \
  || { grep -n -B8 -m1 -E 'make\[[0-9]*\]: \*\*\*|^\*\*\* \[' ../make.log | tail -12 >&2 || true; grep -oE 'error: [^(]{0,60}|Exception[^:]{0,40}|\*\*\* \[[^]]{0,60}\]' ../make.log | sort | uniq -c | sort -rn | head -5 >&2 || true; echo "icedtea-7: make failed" >&2; exit 1; }
[ -x openjdk.build/j2sdk-image/bin/java ] || { echo "icedtea-7: no j2sdk-image" >&2; exit 1; }
mkdir -p "${DST}" && cp -a openjdk.build/j2sdk-image/. "${DST}/"
cd "${BUILDROOT}"
# --- P3 gate: the new javac compiles and the new VM runs a Java 7 program ---
mkdir -p gate; printf 'import java.util.*;\npublic class G { public static void main(String[] a){ List<Integer> l = new ArrayList<>(); for (int i=1;i<=6;i++) l.add(i); int s=0; for (int x : l) s+=x; System.out.println("IT7:"+s+":"+System.getProperty("java.version").substring(0,3)); } }\n' > gate/G.java
( cd gate && "${DST}/bin/javac" G.java )
OUT="$("${DST}/bin/java" -cp gate G 2>&1 | tail -1)"
[ "$OUT" = "IT7:21:1.7" ] || { echo "icedtea-7: gate printed '$OUT'" >&2; exit 1; }

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
            if i.filename.endswith(('.jar', '.zip')) and zipfile.is_zipfile(io.BytesIO(d)): d = norm_bytes(d)
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

mkdir -p "${OUTPUT_DIR}/usr/share/icedtea-7"
cat > "${OUTPUT_DIR}/usr/share/icedtea-7/BUILDINFO" <<EOF
icedtea-7
source: icedtea-2.6.13.tar.xz + 7 OpenJDK drops + 2 patches
boot: ecj4-bootstrap-4.2.1 on jamvm-2.0.0 with classpath-devel; ant-bootstrap-1.8.4
c compiler: gcc ${GCC_VERSION}; sysroot: ${SR}
EOF
echo "icedtea-7: installed to ${PREFIX}"
