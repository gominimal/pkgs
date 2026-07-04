#!/bin/sh
# ============================================================================================
# build.sh — B5 sub-rung (gmp-glibc) driver.  Scaffold 2026-07-04.
# ============================================================================================
# GLIBC-LINKED, SHARED gmp-6.3.0 (libgmp.so.10) — production packages/gmp/build.sh shape, driven by
# R12 gcc-15.2.0 through the PROVEN B5 glibc-retargeting wrapper (binutils-2.46-glibc/build.sh is the
# reference implementation: FIXLIB + -B/-L $SR/lib + baked --dynamic-linker).  as/ld/ar = the SEALED
# binutils-2.46-glibc on PATH (glibc-dynamic tools; interp baked to the B4 loader, libbfd via
# RUNPATH=/usr/lib — hydrated here as a direct build_dep).
#
# ── production packages/gmp/build.sh DELTA ──
#   1. CC = the B5 wrapper (-nostdinc + -isystem $GI + -isystem $SR/include + FIXLIB + -B/-L $SR/lib
#      + -Wl,--dynamic-linker=$SR loader) — every conftest/test binary can EXEC in-sandbox (wall #1:
#      no /lib64 here).
#   2. --disable-cxx (prod --enable-cxx): R12's libstdc++.a is MUSL-built; mixing it into a
#      glibc-dynamic libgmpxx.so is the R4 silent-corruption zone.  CXXFLAGS dropped with it.
#   3. tar --no-same-owner (sandbox userns chown-hostile) + Model-B mtime guard (release tarball
#      ships all generated files; never regenerate).
#   4. KEEP `make check` (production parity — and it exercises the freshly built libgmp.so through
#      libtool's uninstalled-lib wrappers, all exec'ing via the baked B4 interp).
#   5. ADDITIONAL publish: single-writer /usr/lib/gmp-bedrock-6.3.0/{lib,include} for mpfr/mpc-glibc.
#   6. Fail-shut B5-GMP-GATE: link+RUN a tiny mpz program against the fresh libgmp.so via an
#      EXPLICIT loader invocation (walls #1/#3: no /lib64, staged-lib RUNPATH).
# Assembly stays ON (production parity; R12 gcc + binutils-2.46 handle the mpn .asm; m4 in deps) —
# unlike R8's --disable-assembly (a gcc-4.0.4/binutils-2.30 concession).
set -ex
VERSION="${MINIMAL_ARG_VERSION:-6.3.0}"
SRC="gmp-${VERSION}"
BUILDROOT="$(pwd)"
SR=/usr/lib/glibc-bedrock-2.42 # B4: from-source glibc-2.42 versioned sysroot (libc.so + crt*.o + headers + UAPI)
LOADER="${SR}/lib/ld-linux-x86-64.so.2"
VTREE="usr/lib/gmp-bedrock-${VERSION}" # single-writer tree the mpfr/mpc twins consume

command -v gcc >/dev/null 2>&1 || { echo "B5 infra: gcc (R12, gcc-15.2.0) not on PATH" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "B5 infra: as (binutils-2.46-glibc) not on PATH" >&2; exit 1; }
# binutils-2.46-glibc's as is glibc-DYNAMIC (libbfd RUNPATH=/usr/lib, interp = B4 loader): prove it
# can EXEC before configure buries the failure in a conftest haystack.
as --version >/dev/null 2>&1 || { echo "B5 infra: as present but cannot exec (B4 loader / libbfd hydration?)" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "B5 infra: B4 glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ] || { echo "B5 infra: B4 glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ] || { echo "B5 infra: B4 glibc dynamic loader missing at ${LOADER}" >&2; exit 1; }

# ============================================================================================
# libc.so LINKER-SCRIPT FIX (wall #2, ported VERBATIM from binutils-2.46-glibc): the SEALED B4
# artifact's versioned $SR/lib/libc.so bakes /build/output/... GROUP() paths -> dangling in every
# consumer sandbox.  Regenerate a corrected script in a dir ld searches FIRST (prefix-agnostic sed).
# ============================================================================================
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B5 infra: libc.so fixup failed" >&2; exit 1; }
# libm.so is the SAME linker-script class (GROUP with absolute /usr/lib paths; B4's publish sed only
# rewrote libc.so) and gmp's mp_bases/fac generators (gen-bases/gen-trialdivtab, CC_FOR_BUILD) link
# -lm -> regen it into FIXLIB too so -lm resolves inside the bedrock sysroot, not the coin-flip /usr.
# Guarded: only if it IS a script (grep -I: an ELF/symlink libm.so must NOT be sed-copied).
if [ -f "${SR}/lib/libm.so" ] && grep -Iq 'GROUP' "${SR}/lib/libm.so" 2>/dev/null; then
  sed -E "s@[^ ()]*/(libm\.so\.6|libmvec\.so\.1)@${SR}/lib/\1@g" \
    "${SR}/lib/libm.so" > "${FIXLIB}/libm.so"
fi

# ============================================================================================
# CC WRAPPER — R12's gcc, glibc-retargeted (the PROVEN binutils-2.46-glibc wrapper, verbatim).
# -nostdinc + explicit -isystem -> immune to minimal's coin-flip /usr; --dynamic-linker baked ->
# every produced binary (conftests, libtool test wrappers, the .so itself) execs in-sandbox.
# No CXX wrapper: --disable-cxx means configure never probes C++.
# ============================================================================================
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -L "${FIXLIB}" -B "\$SR/lib" -L "\$SR/lib" -Wl,--dynamic-linker="\$SR/lib/ld-linux-x86-64.so.2" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# --- unpack (--no-same-owner: sandbox userns chown-hostile) ---
tar --no-same-owner -xf "${SRC}.tar.xz"
cd "${SRC}"

# Model-B mtime guard: release tarball ships every generated file (configure, Makefile.in, .info);
# bump them newest so make never invokes an absent autoreconf/automake/makeinfo.  THEN the sed below
# bumps configure newest of all (correct order: nothing regenerates FROM configure).
find . \( -name configure -o -name 'Makefile.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
          -o -name '*.m4' -o -name '*.info*' -o -name '*.1' -o -name '*.pod' \) -exec touch {} +

# production parity: fix GMP's "long long reliability test 1" for gcc (x86_64 branch of prod build.sh).
sed -i '/long long t1;/,+1s/()/(...)/' configure

# ── production CFLAGS verbatim (-std=gnu17: gcc-15 defaults gnu23, gmp configure tests are pre-C23;
#    -march/-O2/-pipe/determinism flags = prod).  The wrapper layers -nostdinc/-isystem on top. ──
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -std=gnu17 -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# production flags minus --enable-cxx (musl-libstdc++ mixing hazard; see build.ncl DELTA #2).
CC="${GCCCC}" AR=ar RANLIB=ranlib ./configure \
  --prefix=/usr \
  --enable-shared --disable-static \
  --disable-cxx \
  --docdir="/usr/share/doc/gmp-${VERSION}"

make -j"$(nproc)"
make check
make DESTDIR="${OUTPUT_DIR}" install

# ============================================================================================
# single-writer versioned tree — /usr/lib/gmp-bedrock-6.3.0/{lib,include}.  Consumers (mpfr-glibc,
# mpc-glibc) point --with-gmp-lib/--with-gmp-include here: -nostdinc-safe, immune to the /usr coin
# flip.  Libs only (no .la: those bake libdir=/usr/lib and consumers link -lgmp directly).
# ============================================================================================
VDEST="${OUTPUT_DIR}/${VTREE}"
mkdir -p "${VDEST}/lib" "${VDEST}/include"
cp -a "${OUTPUT_DIR}/usr/include/." "${VDEST}/include/"
cp -a "${OUTPUT_DIR}/usr/lib/"libgmp.so* "${VDEST}/lib/"

# ============================================================================================
# B5-GMP-GATE — link+RUN a tiny mpz program against the FRESH libgmp.so.  Direct gcc call (bypasses
# the wrapper) -> needs FIXLIB itself; run via EXPLICIT loader (wall #1) with --library-path over
# the staged lib (wall #3: its RUNPATH=/usr/lib points at the not-yet-installed location).  FAIL-SHUT.
# ============================================================================================
GATE="${BUILDROOT}/gmpgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
cat > "${GATE}/t.c" <<'EOF'
#include <gmp.h>
int main(void) {
  mpz_t a, b;
  mpz_init_set_ui(a, 6);
  mpz_init_set_ui(b, 7);
  mpz_mul(a, a, b);
  return (int)mpz_get_ui(a); /* 42 */
}
EOF
set +e
/usr/bin/gcc -nostdinc -isystem "${GI}" -isystem "${SR}/include" -I "${OUTPUT_DIR}/usr/include" \
  -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" -L "${OUTPUT_DIR}/usr/lib" \
  "${GATE}/t.c" -lgmp -o "${GATE}/t" 2>"${GATE}/err"
crc=$?
rrc=1
if [ "${crc}" -eq 0 ]; then
  "${LOADER}" --library-path "${OUTPUT_DIR}/usr/lib:${SR}/lib" "${GATE}/t"; rrc=$?
fi
set -e
if [ "${crc}" -eq 0 ] && [ "${rrc}" -eq 42 ]; then
  echo "B5-GMP-GATE: PASS (fresh glibc-linked libgmp.so linked+ran; 6*7=${rrc})" >&2
else
  echo "B5-GMP-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -8 "${GATE}/err" >&2 || true
  exit 1
fi
