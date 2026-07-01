#!/bin/sh
# build.sh — R7 (stage0-musl-1.2.5) driver.  The MODERN libc — FIRST bedrock rung built by a real gcc.
#
# CC = the from-source gcc-4.0.4 (R6), via a gcc-cc WRAPPER that forces it onto R4b's clean musl-bedrock
# sysroot (our gcc's baked search points at the coin-flip /usr).  as/ld/ar/ranlib = binutils-2.30 (R5).
# Because gcc is a real compiler, this is a STOCK musl build — ZERO of R4's tcc-workaround patches:
#   skip-pic-crt / drop-dynamic-crt / amd64-va-list / amd64-syscall-arch / SSE asm-rm / @PLT strip /
#   the tcc-ar empty-archive touch  -> ALL DROPPED (gcc + binutils handle every one natively).
# If a wall appears it should be gcc-4.0.4-is-a-2005-compiler C-compat, not codegen (keystone died at R6).
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.2.5}"
SRC="musl-${VERSION}"
BUILDROOT="$(pwd)"

command -v gcc >/dev/null 2>&1 || { echo "R7 infra error: gcc (R6) not on PATH (broken gcc-4.0.4 edge)" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "R7 infra error: as (R5 binutils-2.30) not on PATH" >&2; exit 1; }
command -v ar  >/dev/null 2>&1 || { echo "R7 infra error: ar (R5 binutils-2.30) not on PATH" >&2; exit 1; }

# ============================================================================================
# §WRAPPER — gcc-cc: our gcc-4.0.4 forced onto R4b's clean /usr/lib/musl-bedrock sysroot.
#   COMPILE (-c/-S/-E): `-nostdinc -isystem <gcc-freestanding>` — musl ships its OWN 1.2.5 headers
#     (it passes `-nostdinc -Iinclude` in "$@"), so we add ONLY gcc's stddef.h/stdarg.h, NEVER R4b's
#     1.1.24 libc headers (that would cross-contaminate 1.2.5's build).  -nostdinc here also blocks
#     the coin-flip glibc /usr/include for any compile where musl doesn't already pass -nostdinc.
#   LINK (no -c): additionally `-isystem $MB/include` (R4b libc headers so configure PROBES that
#     #include <stdio.h> resolve) + `-B/-L $MB/lib -static` (musl crt + libc.a; gcc's driver finds
#     musl crt1/crti/crtn via -B, resolves -lc to $MB/lib/libc.a via -L).  musl's `make` never links
#     an executable (only -c + ar), so this path serves configure probes only.
# ============================================================================================
GI="$(gcc -print-file-name=include)"      # gcc-4.0.4's own freestanding header dir (stddef/stdarg/...)
MB=/usr/lib/musl-bedrock                   # R4b clean musl sysroot (bootstrap link libc for probes)
[ -d "$GI" ] || { echo "R7 infra error: gcc freestanding include dir not found ('$GI')" >&2; exit 1; }
[ -f "$MB/lib/libc.a" ] || { echo "R7 infra error: R4b musl-bedrock sysroot missing at $MB" >&2; exit 1; }

cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"
MB="${MB}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$MB/include" -B "\$MB/lib" -L "\$MB/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# ============================================================================================
# BUILD — stock musl, single deterministic pass (gcc has no arena lottery).
# ============================================================================================
cd "${BUILDROOT}"
rm -rf "${SRC}"
tar -xf "${SRC}.tar.gz"      # Source is extract=false; unpack per the bash-build convention
cd "${SRC}"

# NO PATCHES.  (R4's makefile.patch/madvise/avoid_sys_clone/disable_ctype_headers/skip-pic-crt/
# drop-dynamic-crt/amd64-va-list/amd64-syscall-arch were all tcc-0.9.27 / mes-libc-era workarounds;
# gcc-4.0.4 + binutils-2.30 need none of them.  Add a patch here ONLY if a real gcc-4.0.4 C-compat
# wall appears — and record it in docs/bedrock-patch-provenance.md.)

# --- configure: CC=gcc-cc wrapper; static; install layout baked to /usr, redirected via DESTDIR. ---
CC="${GCCCC}" ./configure \
    --host=x86_64 \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib \
    --includedir=/usr/include

# --- compile + install.  CROSS_COMPILE= blanks the x86_64- prefix; AR/RANLIB = binutils-2.30 (real
#     `ar`/`ranlib` exist now — R5).  -w silences gcc-4.0.4's musl-2020s-source warning storm. ---
make CROSS_COMPILE= CC="${GCCCC}" AR=ar RANLIB=ranlib CFLAGS="-w"
rm -rf "${OUTPUT_DIR}/usr"
make CROSS_COMPILE= CC="${GCCCC}" AR=ar RANLIB=ranlib CFLAGS="-w" \
     DESTDIR="${OUTPUT_DIR}" install

# ============================================================================================
# §SYSROOT — CLEAN SINGLE-WRITER MUSL SYSROOT, VERSIONED (bedrock anti-pollution; see build.ncl).
# Published at /usr/lib/musl-bedrock-1.2.5 (distinct from R4b's /usr/lib/musl-bedrock, so the two musls
# never collide in a downstream sandbox's unordered /usr merge).  R8+ point their gcc-cc wrapper here.
# ============================================================================================
SYSROOT="${OUTPUT_DIR}/usr/lib/musl-bedrock-1.2.5"
mkdir -p "${SYSROOT}/lib"
cp -a "${OUTPUT_DIR}/usr/include" "${SYSROOT}/include"
cp -a "${OUTPUT_DIR}"/usr/lib/*.a "${OUTPUT_DIR}"/usr/lib/*.o "${SYSROOT}/lib/"

# ============================================================================================
# FLOAT + printf CORRECTNESS GATE  [FAIL-SHUT — gcc is deterministic, no re-roll]
# Compile+link+RUN a tiny printf against the JUST-BUILT musl-1.2.5 (explicit crt/libc from $OUTPUT_DIR,
# NOT the R4b bootstrap libc) exactly as a static gcc-cc link would.  A failure here is a REAL codegen/
# libc defect (gcc-4.0.4 or the musl source), NOT a lottery — exit 1 hard (plain BuildScriptFailed).
# ============================================================================================
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
# static musl-1.2.5 link: gcc's driver + -B/-L at the JUST-BUILT musl (its own crt/libc), gcc's own libgcc.
gcc -nostdinc -isystem "${GI}" -isystem "${OUT_INC}" \
    -B "${OUT_LIB}" -L "${OUT_LIB}" -static \
    "${GATEDIR}/floatgate.c" -o "${GATEDIR}/floatgate"
glrc=$?
if [ ${glrc} -eq 0 ]; then
  GATE_OUT="$(timeout 15 "${GATEDIR}/floatgate")" || GATE_OUT="<runtime-crash-or-timeout>"
fi
set -e

if [ "${GATE_OUT}" = "3.75 2.0" ]; then
  echo "R7-FLOAT-GATE: PASS (got '${GATE_OUT}')" >&2
else
  echo "R7-FLOAT-GATE: FAIL (link-rc=${glrc} got '${GATE_OUT}', want '3.75 2.0')" >&2
  echo "R7 build FAILED: printf/float correctness gate did not pass against the just-built musl-1.2.5." >&2
  echo "  gcc-4.0.4 is DETERMINISTIC -> a REAL codegen/libc defect (not a lottery); a re-enqueue reproduces it." >&2
  exit 1
fi

# ============================================================================================
# BYTE-IDENTITY SEAL — record-at-pin-time (gcc is deterministic, so byte-identity is a REAL invariant;
# stage0.answers ships an UNPINNED placeholder for the capture build, promotable to fatal once pinned).
# ============================================================================================
SEAL_FATAL="${SEAL_FATAL:-0}"
cd "${OUTPUT_DIR}"
if head -1 "${BUILDROOT}/stage0.answers" 2>/dev/null | grep -q '^# UNPINNED'; then
  echo "R7 byte-identity seal: NOT YET PINNED — record from this roll: sha256sum usr/lib/libc.a usr/lib/*.o" >&2
else
  if sha256sum -c "${BUILDROOT}/stage0.answers"; then
    echo "R7 byte-identity seal: MATCH (deterministic build reproduced the pinned reference)." >&2
  else
    echo "WARNING: R7 byte-identity seal MISMATCH (gcc is deterministic -> real reproducibility failure)." >&2
    [ "${SEAL_FATAL}" = 1 ] && { echo "  SEAL_FATAL=1 -> failing." >&2; exit 1; }
    echo "  SEAL_FATAL=0 (capture window) -> non-fatal; re-capture stage0.answers, then set SEAL_FATAL=1." >&2
  fi
fi
