#!/bin/bash
# OpenJDK from the openjdk/jdk25u tag archive, booted by ../openjdk-25 (the top of the JVM ladder) and
# compiled by the production toolchain. Installs at /usr/lib/jvm; every tool is linked from /usr/bin.
set -eu
trap 'echo "jdk-25: failed at line $LINENO: $BASH_COMMAND" >&2' ERR

BUILDROOT="$(pwd)"
DST="${OUTPUT_DIR}/usr/lib/jvm"
BOOT=/usr/lib/openjdk-25
JOBS="$(nproc 2>/dev/null || echo 4)"
export HOME="${BUILDROOT}/home"; mkdir -p "$HOME"
export TMPDIR="${BUILDROOT}/tmp"; mkdir -p "$TMPDIR"
export TAR_OPTIONS=--no-same-owner   # the sandbox cannot chown

for x in "${BOOT}/bin/javac" "${BOOT}/bin/java" /usr/include/gif_lib.h /usr/include/freetype2/freetype/freetype.h /usr/include/X11/Intrinsic.h; do
  [ -e "$x" ] || { echo "jdk-25: missing build input $x" >&2; exit 1; }
done

# gnu17: gcc 15 defaults to C23, where hotspot's `typedef int bool;` (agent/src/os/linux/libproc.h) is an error.
# hotspot takes gcc from PATH, the rest of the build from CC
CCDIR="${BUILDROOT}/cc"; mkdir -p "${CCDIR}"
printf '#!/bin/sh\nexec "%s" -std=gnu17 "$@"\n' "$(command -v gcc)" > "${CCDIR}/gcc"
chmod 0755 "${CCDIR}/gcc"
export CC="${CCDIR}/gcc" CXX="$(command -v g++)"

mkdir src && tar -xzf "jdk-${MINIMAL_ARG_VERSION}-ga.tar.gz" -C src --strip-components=1
cd src
# aarch64 HotSpot: interp_masm_aarch64.hpp declares `using MacroAssembler::call_VM_leaf_base;` twice in some
# releases, which gcc 11+ rejects; keep one, next to the call_VM_base comment (Guix's patch-for-aarch64)
python3 - src/hotspot/cpu/aarch64/interp_masm_aarch64.hpp <<'PYEOF'
import sys
p = sys.argv[1]; s = open(p).read()
u = "using MacroAssembler::call_VM_leaf_base;"
c = "Interpreter specific version of call_VM_base"
if s.count(u) > 1:
    s = s.replace(u, "")
    assert s.count(c) == 1, "call_VM_base comment"
    s = s.replace(c, c + "\n  " + u)
    open(p, "w").write(s)
assert open(p).read().count(u) <= 1, p
PYEOF
# glibc 2.42+ <stdlib.h> declares uabs(int); hotspot's inline overloads of the same name collide
grep -rl '\buabs\b' src/hotspot 2>/dev/null | xargs -r sed -i 's/\buabs\b/hs_uabs/g'
# test binaries and jars in the tree; none feed the image
find . -type f \( -name '*.bin' -o -name '*.exe' -o -name '*.jar' \) -delete
sed -i 's/__DATE__/""/; s/__TIME__/""/' src/hotspot/share/runtime/abstract_vm_version.cpp
# the bundled libpng turns on its ARM NEON paths on aarch64, but the JDK build never compiles libpng's neon
# sources (undefined png_init_filter_functions_neon): pin them off
for f in $(find . -path '*libpng/pngpriv.h' -type f); do
  { printf '#ifndef PNG_ARM_NEON_OPT\n#define PNG_ARM_NEON_OPT 0\n#endif\n'; cat "$f"; } > "$f.neon" && mv "$f.neon" "$f"
done
echo "${MINIMAL_ARG_VERSION}" > .src-rev

export JAVA_HOME="${BOOT}" PATH="${BOOT}/bin:${CCDIR}:${PATH}"
# jmod rejects the sandbox's pre-1980 SOURCE_DATE_EPOCH (0): configure takes the date directly.
# extra-cflags come last in the JDK's CFLAGS: gnu17 keeps gcc 15 off C23 (K&R `()` prototypes in libnet's gio
# shims), and gcc 14's incompatible-pointer-types error is a warning again (jtreg's libTestJNI.c)
bash ./configure --with-boot-jdk="${BOOT}" --with-build-user=minimal --disable-warnings-as-errors --with-native-debug-symbols=none \
  "--with-extra-cflags=-std=gnu17 -Wno-error=int-conversion -Wno-error=incompatible-pointer-types" --without-gtest \
  --with-version-pre= --with-version-opt= --with-version-build="${MINIMAL_ARG_BUILD_NUM}" --with-vendor-name=minimal \
  --with-hotspot-build-time=1970-01-01T00:00:01 --enable-reproducible-build --with-source-date=315532802 \
  --with-giflib=system --with-lcms=system --with-libjpeg=system --with-libpng=system --with-zlib=system \
  --with-freetype-include=/usr/include/freetype2 --with-freetype-lib=/usr/lib > ../configure.log 2>&1 \
  || { grep -n -iE 'error|could not|cannot|not found' ../configure.log | tail -8 >&2 || true; echo "jdk-25: configure failed" >&2; exit 1; }
# `images` rather than `all`: `all` adds the static launcher, which nothing here ships
make JOBS="${JOBS}" images > ../make.log 2>&1 \
  || { grep -nE 'error:|Error [0-9]|\*\*\* \[' ../make.log | grep -v Werror | tail -8 >&2 || true; tail -10 ../make.log >&2; echo "jdk-25: make failed" >&2; exit 1; }
IMG="$(ls -d build/*/images/jdk | head -1)"
[ -x "${IMG}/bin/java" ] || { echo "jdk-25: no jdk image" >&2; exit 1; }
mkdir -p "${DST}" && cp -a "${IMG}/." "${DST}/"
cd "${BUILDROOT}"

# the new javac compiles and the new VM runs a program of its own language level, reporting the tag's version
mkdir -p gate; printf '%s\n' 'import java.util.*;' 'public class G { public static void main(String[] a){ var xs = List.of(1,2,3,4,5,6); var s = 0; for (var x : xs) s += x; System.out.println("OJ:"+s+":"+Runtime.version()+":"+"ab".repeat(2)); } }' > gate/G.java
( cd gate && "${DST}/bin/javac" G.java )
OUT="$("${DST}/bin/java" -cp gate G 2>&1 | tail -1)"
[ "$OUT" = "OJ:21:${MINIMAL_ARG_VERSION}+${MINIMAL_ARG_BUILD_NUM}:abab" ] || { echo "jdk-25: gate printed '$OUT'" >&2; exit 1; }

# zip entry timestamps and order are build-time noise
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
# src.zip carries generated sources that do not reproduce
find "${DST}" -name 'src.zip' -type f -delete
# the default class list is written in class-load order, which varies run to run; only its membership matters
[ ! -f "${DST}/lib/classlist" ] || { LC_ALL=C sort "${DST}/lib/classlist" > "${DST}/lib/classlist.sorted" && mv "${DST}/lib/classlist.sorted" "${DST}/lib/classlist"; }

mkdir -p "${OUTPUT_DIR}/usr/bin"
for path in "${DST}"/bin/*; do
  bin=$(basename "$path")
  ln -sv "../lib/jvm/bin/$bin" "${OUTPUT_DIR}/usr/bin/$bin"
done
