#!/bin/sh
# ============================================================================================
# build.sh — B5 sub-rung (mpfr-glibc) driver.  Scaffold 2026-07-04.
# ============================================================================================
# GLIBC-LINKED, SHARED mpfr-4.2.2 (libmpfr.so.6) — production packages/mpfr/build.sh shape, R12 gcc
# through the PROVEN B5 wrapper (FIXLIB + -B/-L $SR/lib + baked --dynamic-linker; reference impl:
# binutils-2.46-glibc/build.sh).  gmp = the sibling gmp-glibc via its single-writer versioned tree
# /usr/lib/gmp-bedrock-6.3.0 (NOT the coin-flip-exposed /usr copy).
#
# ── production packages/mpfr/build.sh DELTA ──
#   1. CC = the B5 wrapper (see gmp-glibc/build.sh for the wall classes it neutralizes).
#   2. --with-gmp-lib/--with-gmp-include at the versioned gmp tree; LDFLAGS += -Wl,-rpath,<gmp>/lib
#      (JOINED form — wall #4 libtool pedantry) so configure's gmp.h-vs-libgmp RUN-test conftests and
#      the installed libmpfr.so resolve libgmp without ld.so.cache or /lib64 (walls #1/#3).
#   3. tar --no-same-owner + Model-B mtime guard.
#   4. `make check` stays OFF (production parity — prod comments it out); the fail-shut
#      B5-MPFR-GATE below covers the load-bearing FLOAT path instead (the R4 lesson).
#   5. ADDITIONAL publish: /usr/lib/mpfr-bedrock-4.2.2/{lib,include} for mpc-glibc.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-4.2.2}"
SRC="mpfr-${VERSION}"
BUILDROOT="$(pwd)"
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
GMPV=/usr/lib/gmp-bedrock-6.3.0  # gmp-glibc's single-writer tree
VTREE="usr/lib/mpfr-bedrock-${VERSION}"

command -v gcc >/dev/null 2>&1 || { echo "B5 infra: gcc (R12, gcc-15.2.0) not on PATH" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "B5 infra: as (binutils-2.46-glibc) not on PATH" >&2; exit 1; }
as --version >/dev/null 2>&1 || { echo "B5 infra: as present but cannot exec (B4 loader / libbfd hydration?)" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "B5 infra: B4 glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ] || { echo "B5 infra: B4 glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "B5 infra: B4 glibc dynamic loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${GMPV}/include/gmp.h" ] || { echo "B5 infra: gmp-glibc versioned tree missing at ${GMPV} (gmp.h)" >&2; exit 1; }
[ -e "${GMPV}/lib/libgmp.so" ] || { echo "B5 infra: gmp-glibc versioned tree missing at ${GMPV} (libgmp.so)" >&2; exit 1; }

# libc.so LINKER-SCRIPT FIX (wall #2) — verbatim from binutils-2.46-glibc/build.sh:
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B5 infra: libc.so fixup failed" >&2; exit 1; }
# libm.so is the SAME linker-script class (GROUP with absolute /usr/lib paths; B4's publish sed only
# rewrote libc.so) and mpfr's configure math-lib probe links -lm -> regen it into FIXLIB too so -lm
# resolves inside the bedrock sysroot, not the coin-flip /usr.  Guarded: only if it IS a script
# (grep -I: an ELF/symlink libm.so must NOT be sed-copied).
if [ -f "${SR}/lib/libm.so" ] && grep -Iq 'GROUP' "${SR}/lib/libm.so" 2>/dev/null; then
  sed -E "s@[^ ()]*/(libm\.so\.6|libmvec\.so\.1)@${SR}/lib/\1@g" \
    "${SR}/lib/libm.so" > "${FIXLIB}/libm.so"
fi

# CC WRAPPER — the proven B5 glibc-retargeting wrapper (gmp include/lib come in via configure's
# --with-gmp-* flags, so the wrapper stays the verbatim binutils-2.46-glibc one):
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -L "${FIXLIB}" -B "\$SR/lib" -L "\$SR/lib" -Wl,--dynamic-linker="\$SR/lib/ld-linux-x86-64.so.2" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

tar --no-same-owner -xf "${SRC}.tar.xz"
cd "${SRC}"

# Model-B mtime guard (release tarball ships all generated files):
find . \( -name configure -o -name 'Makefile.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
          -o -name '*.m4' -o -name '*.info*' -o -name '*.1' -o -name '*.pod' \) -exec touch {} +

# ── production CFLAGS verbatim; -Wl,-rpath JOINED (wall #4) so libtool passes it through ──
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none -Wl,-rpath,${GMPV}/lib"

# production flags + the explicit versioned-gmp pointers:
CC="${GCCCC}" AR=ar RANLIB=ranlib ./configure \
  --prefix=/usr \
  --enable-shared --disable-static \
  --enable-thread-safe \
  --with-gmp-lib="${GMPV}/lib" \
  --with-gmp-include="${GMPV}/include" \
  --docdir="/usr/share/doc/mpfr-${VERSION}"

make -j"$(nproc)"
#make check   # production parity: off (the gate below covers the float path)
make DESTDIR="${OUTPUT_DIR}" install

# single-writer versioned tree for mpc-glibc (libs only; no .la):
VDEST="${OUTPUT_DIR}/${VTREE}"
mkdir -p "${VDEST}/lib" "${VDEST}/include"
cp -a "${OUTPUT_DIR}/usr/include/." "${VDEST}/include/"
cp -a "${OUTPUT_DIR}/usr/lib/"libmpfr.so* "${VDEST}/lib/"

# ============================================================================================
# B5-MPFR-GATE — link+RUN a FLOAT-path program (mpfr_set_d + mpfr_mul_ui: 10.5 * 4 = 42) against the
# fresh libmpfr.so.  The R4 lesson: float correctness is gated AT the rung that builds the float lib.
# Direct gcc call -> FIXLIB; EXPLICIT loader + --library-path over staged libmpfr + versioned gmp
# (walls #1/#3).  FAIL-SHUT.
# ============================================================================================
GATE="${BUILDROOT}/mpfrgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
cat > "${GATE}/t.c" <<'EOF'
#include <mpfr.h>
int main(void) {
  mpfr_t x;
  mpfr_init2(x, 64);
  mpfr_set_d(x, 10.5, MPFR_RNDN);
  mpfr_mul_ui(x, x, 4, MPFR_RNDN); /* 42.0 exactly */
  long r = mpfr_get_si(x, MPFR_RNDN);
  mpfr_clear(x);
  return (int)r;
}
EOF
set +e
/usr/bin/gcc -nostdinc -isystem "${GI}" -isystem "${SR}/include" \
  -I "${OUTPUT_DIR}/usr/include" -I "${GMPV}/include" \
  -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" \
  -L "${OUTPUT_DIR}/usr/lib" -L "${GMPV}/lib" \
  "${GATE}/t.c" -lmpfr -lgmp -o "${GATE}/t" 2>"${GATE}/err"
crc=$?
rrc=1
if [ "${crc}" -eq 0 ]; then
  "${LOADER}" --library-path "${OUTPUT_DIR}/usr/lib:${GMPV}/lib:${SR}/lib" "${GATE}/t"; rrc=$?
fi
set -e
if [ "${crc}" -eq 0 ] && [ "${rrc}" -eq 42 ]; then
  echo "B5-MPFR-GATE: PASS (fresh glibc-linked libmpfr.so float path OK; 10.5*4=${rrc})" >&2
else
  echo "B5-MPFR-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -8 "${GATE}/err" >&2 || true
  exit 1
fi
