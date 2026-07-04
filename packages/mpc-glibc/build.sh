#!/bin/sh
# ============================================================================================
# build.sh — B5 sub-rung (mpc-glibc) driver.  Scaffold 2026-07-04.
# ============================================================================================
# GLIBC-LINKED, SHARED mpc-1.4.0 (libmpc.so.3) — production packages/mpc/build.sh shape, R12 gcc
# through the PROVEN B5 wrapper (reference impl: binutils-2.46-glibc/build.sh).  gmp + mpfr = the
# sibling -glibc twins via their single-writer versioned trees (NOT the coin-flip-exposed /usr).
# Terminal leaf of gmp -> mpfr -> mpc; deltas mirror mpfr-glibc/build.sh exactly (see that file).
set -ex
VERSION="${MINIMAL_ARG_VERSION:-1.4.0}"
SRC="mpc-${VERSION}"
BUILDROOT="$(pwd)"
SR=/usr/lib/glibc-bedrock-2.42
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
GMPV=/usr/lib/gmp-bedrock-6.3.0    # gmp-glibc's single-writer tree
MPFRV=/usr/lib/mpfr-bedrock-4.2.2  # mpfr-glibc's single-writer tree
VTREE="usr/lib/mpc-bedrock-${VERSION}"

command -v gcc >/dev/null 2>&1 || { echo "B5 infra: gcc (R12, gcc-15.2.0) not on PATH" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "B5 infra: as (binutils-2.46-glibc) not on PATH" >&2; exit 1; }
as --version >/dev/null 2>&1 || { echo "B5 infra: as present but cannot exec (B4 loader / libbfd hydration?)" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "B5 infra: B4 glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ] || { echo "B5 infra: B4 glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "B5 infra: B4 glibc dynamic loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${GMPV}/include/gmp.h" ] || { echo "B5 infra: gmp-glibc versioned tree missing at ${GMPV}" >&2; exit 1; }
[ -e "${GMPV}/lib/libgmp.so" ] || { echo "B5 infra: gmp-glibc lib missing at ${GMPV}/lib" >&2; exit 1; }
[ -f "${MPFRV}/include/mpfr.h" ] || { echo "B5 infra: mpfr-glibc versioned tree missing at ${MPFRV}" >&2; exit 1; }
[ -e "${MPFRV}/lib/libmpfr.so" ] || { echo "B5 infra: mpfr-glibc lib missing at ${MPFRV}/lib" >&2; exit 1; }

# libc.so LINKER-SCRIPT FIX (wall #2) — verbatim from binutils-2.46-glibc/build.sh:
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B5 infra: libc.so fixup failed" >&2; exit 1; }
# libm.so is the SAME linker-script class (GROUP with absolute /usr/lib paths; B4's publish sed only
# rewrote libc.so) -> regen it into FIXLIB too (mpc itself never links -lm; kept for trio-identical
# FIXLIB blocks).  Guarded: only if it IS a script (grep -I: an ELF/symlink libm.so must NOT be
# sed-copied).
if [ -f "${SR}/lib/libm.so" ] && grep -Iq 'GROUP' "${SR}/lib/libm.so" 2>/dev/null; then
  sed -E "s@[^ ()]*/(libm\.so\.6|libmvec\.so\.1)@${SR}/lib/\1@g" \
    "${SR}/lib/libm.so" > "${FIXLIB}/libm.so"
fi

# CC WRAPPER — the proven B5 glibc-retargeting wrapper (gmp/mpfr come in via --with-* flags):
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

# ── production CFLAGS verbatim; JOINED -Wl,-rpath for BOTH dep trees (walls #3/#4) ──
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none -Wl,-rpath,${GMPV}/lib -Wl,-rpath,${MPFRV}/lib"

# production flags + explicit versioned gmp/mpfr pointers:
CC="${GCCCC}" AR=ar RANLIB=ranlib ./configure \
  --prefix=/usr \
  --enable-shared --disable-static \
  --with-gmp-lib="${GMPV}/lib" \
  --with-gmp-include="${GMPV}/include" \
  --with-mpfr-lib="${MPFRV}/lib" \
  --with-mpfr-include="${MPFRV}/include" \
  --docdir="/usr/share/doc/mpc-${VERSION}"

make -j"$(nproc)"
#make check   # production parity: off (the gate below covers link+run)
make DESTDIR="${OUTPUT_DIR}" install

# single-writer versioned tree (libs only; no .la):
VDEST="${OUTPUT_DIR}/${VTREE}"
mkdir -p "${VDEST}/lib" "${VDEST}/include"
cp -a "${OUTPUT_DIR}/usr/include/." "${VDEST}/include/"
cp -a "${OUTPUT_DIR}/usr/lib/"libmpc.so* "${VDEST}/lib/"

# ============================================================================================
# B5-MPC-GATE — link+RUN a complex-arithmetic program against the fresh libmpc.so:
# (6+1i)*(7+0i) = 42+7i; verify BOTH parts, exit 42 on success.  Direct gcc call -> FIXLIB;
# EXPLICIT loader + --library-path over staged libmpc + both dep trees (walls #1/#3).  FAIL-SHUT.
# ============================================================================================
GATE="${BUILDROOT}/mpcgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
cat > "${GATE}/t.c" <<'EOF'
#include <mpc.h>
int main(void) {
  mpc_t z, w;
  mpc_init2(z, 64);
  mpc_init2(w, 64);
  mpc_set_ui_ui(z, 6, 1, MPC_RNDNN);
  mpc_set_ui_ui(w, 7, 0, MPC_RNDNN);
  mpc_mul(z, z, w, MPC_RNDNN); /* 42 + 7i */
  long re = mpfr_get_si(mpc_realref(z), MPFR_RNDN);
  long im = mpfr_get_si(mpc_imagref(z), MPFR_RNDN);
  mpc_clear(z);
  mpc_clear(w);
  return (re == 42 && im == 7) ? 42 : 1;
}
EOF
set +e
/usr/bin/gcc -nostdinc -isystem "${GI}" -isystem "${SR}/include" \
  -I "${OUTPUT_DIR}/usr/include" -I "${MPFRV}/include" -I "${GMPV}/include" \
  -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" \
  -L "${OUTPUT_DIR}/usr/lib" -L "${MPFRV}/lib" -L "${GMPV}/lib" \
  "${GATE}/t.c" -lmpc -lmpfr -lgmp -o "${GATE}/t" 2>"${GATE}/err"
crc=$?
rrc=1
if [ "${crc}" -eq 0 ]; then
  "${LOADER}" --library-path "${OUTPUT_DIR}/usr/lib:${MPFRV}/lib:${GMPV}/lib:${SR}/lib" "${GATE}/t"; rrc=$?
fi
set -e
if [ "${crc}" -eq 0 ] && [ "${rrc}" -eq 42 ]; then
  echo "B5-MPC-GATE: PASS (fresh glibc-linked libmpc.so complex mul OK; (6+i)*(7)=42+7i)" >&2
else
  echo "B5-MPC-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -8 "${GATE}/err" >&2 || true
  exit 1
fi
