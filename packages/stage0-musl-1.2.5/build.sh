#!/bin/sh
# stage0-musl-1.2.5: build stock musl 1.2.5 with gcc-4.0.4 and binutils-2.30 and install libc.a,
# crt*.o and headers under $OUTPUT_DIR. No patches.
# phases: preconditions, gcc-cc wrapper, unpack, configure, make, sysroot copy, float gate, sha256 seal
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.2.5}"
SRC="musl-${VERSION}"
BUILDROOT="$(pwd)"

command -v gcc >/dev/null 2>&1 || { echo "musl-1.2.5: gcc (gcc-4.0.4) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "musl-1.2.5: as (binutils-2.30) not on PATH" >&2; exit 1; }
command -v ar  >/dev/null 2>&1 || { echo "musl-1.2.5: ar (binutils-2.30) not on PATH" >&2; exit 1; }

# --- gcc-cc wrapper ---
# gcc's baked include/lib search points at the merged /usr, which glibc also writes in the sandbox.
# Compile (-c/-S/-E): `-nostdinc -isystem <gcc's own headers>` only. musl passes -nostdinc -Iinclude
# itself, so gcc's stddef.h/stdarg.h are added but never the 1.1.24 libc headers.
# Link: additionally -isystem/-B/-L on the 1.1.24 musl-bedrock sysroot, -static, so configure's probe
# links resolve musl crt and libc. musl's make never links an executable, so this serves probes only.
GI="$(gcc -print-file-name=include)"      # gcc's own header dir (stddef/stdarg/...)
MB=/usr/lib/musl-bedrock                   # 1.1.24 musl sysroot, link libc for probes
[ -d "$GI" ] || { echo "musl-1.2.5: gcc freestanding include dir not found ('$GI')" >&2; exit 1; }
[ -f "$MB/lib/libc.a" ] || { echo "musl-1.2.5: musl-1.1.24 sysroot missing at $MB" >&2; exit 1; }

cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"
MB="${MB}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$MB/include" -B "\$MB/lib" -L "\$MB/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# --- unpack (Source is extract=false) ---
cd "${BUILDROOT}"
rm -rf "${SRC}"
tar -xof "${SRC}.tar.gz"
cd "${SRC}"

# No patches: the tcc-era musl patches are not needed with gcc and binutils.

# --- configure: static only; prefix /usr, redirected via DESTDIR at install ---
CC="${GCCCC}" ./configure \
    --host=x86_64 \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib \
    --includedir=/usr/include

# --- compile + install ---
# CROSS_COMPILE= blanks the x86_64- prefix configure would add to AR/RANLIB. -w silences gcc-4.0.4's
# warnings on musl's newer source.
make CROSS_COMPILE= CC="${GCCCC}" AR=ar RANLIB=ranlib CFLAGS="-w"
rm -rf "${OUTPUT_DIR}/usr"
make CROSS_COMPILE= CC="${GCCCC}" AR=ar RANLIB=ranlib CFLAGS="-w" \
     DESTDIR="${OUTPUT_DIR}" install

# --- versioned sysroot copy ---
# Distinct from the 1.1.24 musl-bedrock path so the two musls never collide in a consumer sandbox's
# merged /usr. Later rungs point their gcc wrapper here.
SYSROOT="${OUTPUT_DIR}/usr/lib/musl-bedrock-1.2.5"
mkdir -p "${SYSROOT}/lib"
cp -a "${OUTPUT_DIR}/usr/include" "${SYSROOT}/include"
cp -a "${OUTPUT_DIR}"/usr/lib/*.a "${OUTPUT_DIR}"/usr/lib/*.o "${SYSROOT}/lib/"

# --- float/printf gate ---
# Compile, link and run a small printf against the just-built musl (explicit crt/libc from
# $OUTPUT_DIR, not the 1.1.24 libc). gcc is deterministic, so a failure is a real codegen or libc
# defect and the build exits 1.
GATEDIR="${BUILDROOT}/float-gate"
rm -rf "${GATEDIR}"; mkdir -p "${GATEDIR}"
OUT_LIB="${OUTPUT_DIR}/usr/lib"
OUT_INC="${OUTPUT_DIR}/usr/include"

cat > "${GATEDIR}/floatgate.c" <<'FLOATGATE'
#include <stdio.h>
int main(void){ volatile double a=1.5,b=2.25; long double c=0x1p28L; printf("%.2f %.1Lf\n", a+b, (long double)(c/0x1p27L)); return 0; }
FLOATGATE

GATE_OUT="<compile-or-link-failed>"
set +e
gcc -nostdinc -isystem "${GI}" -isystem "${OUT_INC}" \
    -B "${OUT_LIB}" -L "${OUT_LIB}" -static \
    "${GATEDIR}/floatgate.c" -o "${GATEDIR}/floatgate"
glrc=$?
if [ ${glrc} -eq 0 ]; then
  GATE_OUT="$(timeout 15 "${GATEDIR}/floatgate")" || GATE_OUT="<runtime-crash-or-timeout>"
fi
set -e

if [ "${GATE_OUT}" = "3.75 2.0" ]; then
  echo "FLOAT-GATE: PASS (got '${GATE_OUT}')" >&2
else
  echo "FLOAT-GATE: FAIL (link-rc=${glrc} got '${GATE_OUT}', want '3.75 2.0')" >&2
  echo "musl-1.2.5 build FAILED: printf/float correctness gate did not pass against the just-built musl-1.2.5." >&2
  echo "  gcc-4.0.4 is deterministic: this is a real codegen/libc defect and a rebuild reproduces it." >&2
  exit 1
fi

# --- byte-identity seal ---
# While stage0.answers starts with `# UNPINNED` the hashes are only printed. Once pinned, paths are
# checked relative to $OUTPUT_DIR; a mismatch is fatal only with SEAL_FATAL=1.
SEAL_FATAL="${SEAL_FATAL:-0}"   # set to 1 once stage0.answers is pinned
cd "${OUTPUT_DIR}"
if head -1 "${BUILDROOT}/stage0.answers" 2>/dev/null | grep -q '^# UNPINNED'; then
  echo "musl-1.2.5 byte-identity seal: NOT YET PINNED — record from this build: sha256sum usr/lib/libc.a usr/lib/*.o" >&2
else
  if sha256sum -c "${BUILDROOT}/stage0.answers"; then
    echo "musl-1.2.5 byte-identity seal: MATCH (deterministic build reproduced the pinned reference)." >&2
  else
    echo "WARNING: musl-1.2.5 byte-identity seal MISMATCH (gcc is deterministic -> real reproducibility failure)." >&2
    [ "${SEAL_FATAL}" = 1 ] && { echo "  SEAL_FATAL=1 -> failing." >&2; exit 1; }
    echo "  SEAL_FATAL=0 (capture window) -> non-fatal; re-capture stage0.answers, then set SEAL_FATAL=1." >&2
  fi
fi
