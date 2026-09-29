#!/bin/sh
# stage0-musl-1.1.24-cc2: build musl 1.1.24 with tcc-musl2 (a musl-linked tcc-0.9.27) and install
# libc.a, crt*.o and headers under $OUTPUT_DIR. Same source and patches as stage0-musl-1.1.24;
# tcc-musl2's codegen is deterministic, so there is no compile retry and the float gate fails hard.
# CC=tcc-musl2 compiles every .c and assembles every .s (no binutils yet); AR="tcc-musl2 -ar".
# phases: preconditions, unpack, patch, source pruning, configure, make, sysroot copy, float gate, sha256 seal
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"
# Local files (build.sh, *.patch, stage0.answers) sit in the build root.
BUILDROOT="$(pwd)"

# tcc-musl2 bakes CONFIG_TCCDIR=/usr/lib/tcc, so its libtcc1.a is at /usr/lib/tcc/libtcc1.a;
# the float gate links against it.
CC_MUSL2="/usr/bin/tcc-musl2"
LIBTCC1="/usr/lib/tcc/libtcc1.a"
command -v tcc-musl2 >/dev/null 2>&1 || { echo "musl-1.1.24-cc2: tcc-musl2 not on PATH (stage0-tcc-0.9.27-musl-s3 did not provide it)" >&2; exit 1; }
[ -f "${LIBTCC1}" ] || { echo "musl-1.1.24-cc2 float-gate: libtcc1.a missing at ${LIBTCC1} (stage0-tcc-0.9.27-musl-s3 did not provide it)" >&2; exit 1; }

# --- unpack (Source is extract=false) ---
cd "${BUILDROOT}"
rm -rf "${SRC}"
tar -xof "${SRC}.tar.gz"
cd "${SRC}"

# --- patches: four arch-neutral live-bootstrap patches, then four amd64 patches for tcc limits ---
patch -Np1 -i "${BUILDROOT}/makefile.patch"               # tcc -ar cannot create empty archives; touch them
patch -Np1 -i "${BUILDROOT}/madvise_preserve_errno.patch" # preserve errno across __madvise
patch -Np1 -i "${BUILDROOT}/avoid_sys_clone.patch"        # posix_spawn: fork() instead of __clone
patch -Np1 -i "${BUILDROOT}/disable_ctype_headers.patch"  # drop iswalpha/... decls (no table regen)
patch -Np1 -i "${BUILDROOT}/skip-pic-crt.patch"           # drop Scrt1.o/rcrt1.o (tcc crashes on the -fPIC crt)
patch -Np1 -i "${BUILDROOT}/drop-dynamic-crt.patch"       # drop the _DYNAMIC lea from crt_arch.h
patch -Np1 -i "${BUILDROOT}/amd64-va-list.patch"          # define va_list for tcc
patch -Np1 -i "${BUILDROOT}/amd64-syscall-arch.patch"     # __syscall4/5/6 without register-asm pinning

# tcc has no _Complex and cannot build iconv. src/ctype/ is kept whole: the wide-ctype files
# compile under tcc-musl2, and binutils links iswalpha and towlower.
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c
rm -rf src/complex

# tcc-0.9.27's assembler cannot handle musl's x86_64 SSE math/fenv .s files (stmxcsr/ldmxcsr and
# others); all have C fallbacks, so remove the asm and let musl build the C versions.
# setjmp.s, longjmp.s and sigsetjmp.s stay: they have no C fallback and binutils links sigsetjmp.
rm -f src/math/x86_64/*.s src/fenv/x86_64/*.s

# tcc-0.9.27's assembler rejects the `@PLT` suffix in sigsetjmp.s (`call setjmp@PLT`). This is a
# static build, so a direct `call setjmp` is correct.
sed -i 's/@PLT//g' src/signal/x86_64/sigsetjmp.s

# --- configure: static only; prefix /usr, redirected via DESTDIR at install ---
CC="${CC_MUSL2}" ./configure \
    --host=x86_64 \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib \
    --includedir=/usr/include

# --- compile + install ---
# CROSS_COMPILE= blanks the x86_64- prefix configure would add to AR/RANLIB. CFLAGS=-DSYSCALL_NO_TLS
# matches live-bootstrap (errno without TLS). No -O/-march: tcc rejects them.
make CROSS_COMPILE= CC="${CC_MUSL2}" AR="tcc-musl2 -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w"
rm -rf "${OUTPUT_DIR}/usr"
make CROSS_COMPILE= CC="${CC_MUSL2}" AR="tcc-musl2 -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w" \
     DESTDIR="${OUTPUT_DIR}" install

# --- sysroot copy ---
# In consumer sandboxes the merged /usr/{include,lib} is also written by glibc (runtime dep of the
# shell tools) and the rootfs overlay is first-writer-wins, so consumers compile and link
# -nostdinc with explicit crt/libc against this copy, which no other package writes.
# $OUTPUT_DIR/usr here is this build's own install, so the copy is pure musl.
SYSROOT="${OUTPUT_DIR}/usr/lib/musl-bedrock"
mkdir -p "${SYSROOT}/lib"
cp -a "${OUTPUT_DIR}/usr/include" "${SYSROOT}/include"
cp -a "${OUTPUT_DIR}"/usr/lib/*.a "${OUTPUT_DIR}"/usr/lib/*.o "${SYSROOT}/lib/"

# --- float/printf gate ---
# The mes-linked tcc sometimes emitted fmt_fp's long double constants (src/stdio/vfprintf.c) as
# zero in .data, so every %f printed 0.00. Compile, link and run a small printf against the
# just-built musl exactly as a static musl-cc link would. tcc-musl2 is deterministic, so a
# failure is a real codegen or libc defect and the build exits 1.
GATEDIR="${BUILDROOT}/float-gate"
rm -rf "${GATEDIR}"
mkdir -p "${GATEDIR}"
MUSL_LIB="${OUTPUT_DIR}/usr/lib"
MUSL_INC="${OUTPUT_DIR}/usr/include"

cat > "${GATEDIR}/floatgate.c" <<'FLOATGATE'
#include <stdio.h>
int main(void){ volatile double a=1.5,b=2.25; long double c=0x1p28L; printf("%.2f %.1Lf\n", a+b, (long double)(c/0x1p27L)); return 0; }
FLOATGATE

GATE_OUT="<compile-or-link-failed>"
# gate steps run without set -e so a failure yields a diagnostic before exit 1
set +e
"${CC_MUSL2}" -c -nostdinc -I "${MUSL_INC}" -DSYSCALL_NO_TLS \
    "${GATEDIR}/floatgate.c" -o "${GATEDIR}/floatgate.o"
gcrc=$?
# libc.a is repeated so libtcc1<->libc back-references resolve; tcc has no --start-group
"${CC_MUSL2}" -nostdlib -static \
    "${MUSL_LIB}/crt1.o" "${MUSL_LIB}/crti.o" \
    "${GATEDIR}/floatgate.o" \
    "${MUSL_LIB}/libc.a" "${LIBTCC1}" "${MUSL_LIB}/libc.a" \
    "${MUSL_LIB}/crtn.o" \
    -o "${GATEDIR}/floatgate"
glrc=$?
if [ ${gcrc} -eq 0 ] && [ ${glrc} -eq 0 ]; then
  GATE_OUT="$(timeout 15 "${GATEDIR}/floatgate")" || GATE_OUT="<runtime-crash-or-timeout>"
fi
set -e

if [ "${GATE_OUT}" = "3.75 2.0" ]; then
  echo "FLOAT-GATE: PASS (got '${GATE_OUT}')" >&2
else
  echo "FLOAT-GATE: FAIL (compile-rc=${gcrc} link-rc=${glrc} got '${GATE_OUT}', want '3.75 2.0')" >&2
  echo "musl-1.1.24-cc2 build FAILED: the float/printf correctness gate did not pass.  tcc-musl2 is deterministic, so" >&2
  echo "  this is a real codegen/libc defect — a rebuild will reproduce it." >&2
  echo "  Investigate tcc-musl2 fmt_fp long-double .data emission / the musl source." >&2
  exit 1
fi

# --- byte-identity seal ---
# While stage0.answers starts with `# UNPINNED` the hashes are only printed. Once pinned, paths are
# checked relative to $OUTPUT_DIR; a mismatch is fatal only with SEAL_FATAL=1.
SEAL_FATAL="${SEAL_FATAL:-0}"   # set to 1 once stage0.answers is pinned
cd "${OUTPUT_DIR}"
if head -1 "${BUILDROOT}/stage0.answers" 2>/dev/null | grep -q '^# UNPINNED'; then
  echo "musl-1.1.24-cc2 byte-identity seal: NOT YET PINNED (deterministic build) — record stage0.answers from this build:" >&2
  echo "  sha256sum usr/lib/libc.a usr/lib/*.o  (run in \$OUTPUT_DIR), then drop the '# UNPINNED' sentinel." >&2
else
  if sha256sum -c "${BUILDROOT}/stage0.answers"; then
    echo "musl-1.1.24-cc2 byte-identity seal: MATCH (deterministic build reproduced the pinned reference)." >&2
  else
    echo "WARNING: musl-1.1.24-cc2 byte-identity seal MISMATCH." >&2
    echo "  The build is deterministic, so a mismatch against a PINNED reference is a real reproducibility failure." >&2
    if [ "${SEAL_FATAL}" = 1 ]; then
      echo "  SEAL_FATAL=1 -> failing the build." >&2
      exit 1
    fi
    echo "  SEAL_FATAL=0 (capture window) -> non-fatal; re-capture stage0.answers, then set SEAL_FATAL=1." >&2
  fi
fi
