#!/bin/sh
# build.sh — R8 (stage0-gmp-mpfr-mpc) driver.  gcc's exact-arithmetic trio, built by from-source
# gcc-4.0.4 (R6), linked musl-1.2.5 (R7), archived by binutils-2.30 (R5).  Build order gmp -> mpfr -> mpc.
# The "most de-risked rung": three pure-C static libs.  Any wall should be gcc-4.0.4-C-vintage, not codegen.
set -ex
BUILDROOT="$(pwd)"
STAGE="${BUILDROOT}/gcc-math"            # WRITABLE build-local install (logical==physical) so libtool .la
                                         #   cross-refs resolve (mpc's libmpfr.la -> libgmp.la).  A DESTDIR
                                         #   install leaves .la pointing at the read-only /usr libtool can't read.
FINAL="${OUTPUT_DIR}/usr/lib/gcc-math"   # published output tree (R9 --with-gmp/mpfr/mpc => /usr/lib/gcc-math)

# --no-same-owner: sandbox userns can't chown to the archived uid (gmp's tree is owned uid 1006) —
# same reflex as R5/R6.  A plain `tar -xf` exits non-zero "Cannot change ownership ... Invalid argument".
untar() { tar --no-same-owner -xf "$1"; }

command -v gcc >/dev/null 2>&1 || { echo "R8 infra: gcc (R6) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "R8 infra: as (R5 binutils) not on PATH" >&2; exit 1; }

# ============================================================================================
# §WRAPPER — gcc-cc, LIBC-USING variant (gmp/mpfr/mpc #include <stdio.h> etc. -> need musl-1.2.5 libc
# headers on COMPILE, unlike R7's freestanding musl build).  SR = R7's versioned sysroot.
# ============================================================================================
SR=/usr/lib/musl-bedrock-1.2.5
GI="$(gcc -print-file-name=include)"
[ -d "$GI" ] || { echo "R8 infra: gcc freestanding include dir not found ('$GI')" >&2; exit 1; }
[ -f "$SR/lib/libc.a" ] || { echo "R8 infra: R7 musl-1.2.5 sysroot missing at $SR" >&2; exit 1; }
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# Model-B: keep the shipped autoconf `configure`, skip regen.  Belt: touch generated files newest so
# make never invokes the absent autoreconf/automake/aclocal.  (These are release tarballs, so the shipped
# tree is complete; the guard just prevents an mtime inversion from triggering a regen we can't satisfy.)
mtime_guard() { find "$1" \( -name configure -o -name 'Makefile.in' -o -name 'config.h.in' -o -name 'aclocal.m4' -o -name '*.m4' \) -exec touch {} + 2>/dev/null || true; }

build_one() {  # $1 = extracted srcdir ; $2.. = extra configure args
  d="$1"; shift
  ( cd "$d" && mtime_guard . && \
    CC="${GCCCC}" AR=ar RANLIB=ranlib ./configure \
      --prefix="${STAGE}" --disable-shared --enable-static "$@" && \
    make -j1 && \
    make -j1 install )
}

cd "${BUILDROOT}"

# --- gmp: --disable-assembly => generic C mpn (no hand-written x86_64 .asm for gcc-4.0.4/binutils) ---
untar gmp-6.2.1.tar.xz
build_one gmp-6.2.1 --disable-assembly

# --- mpfr: needs gmp (point at the writable staging tree) ---
untar mpfr-4.1.0.tar.xz
build_one mpfr-4.1.0 --with-gmp="${STAGE}"

# --- mpc: needs gmp + mpfr ---
untar mpc-1.2.1.tar.gz
build_one mpc-1.2.1 --with-gmp="${STAGE}" --with-mpfr="${STAGE}"

# --- publish staging -> output.  Drop the .la files: they bake the build-local $STAGE path (dead in R9's
#     sandbox) and R9 links the static .a directly via --with-gmp/mpfr/mpc, never the libtool archives. ---
mkdir -p "${FINAL}"
cp -a "${STAGE}/lib" "${STAGE}/include" "${FINAL}/"
rm -f "${FINAL}/lib"/*.la

# --- sanity gate: the three static libs + their headers must exist in the output ---
for f in lib/libgmp.a lib/libmpfr.a lib/libmpc.a include/gmp.h include/mpfr.h include/mpc.h; do
  [ -f "${FINAL}/${f}" ] || { echo "R8 FAIL: missing ${FINAL}/${f}" >&2; exit 1; }
done
echo "R8: gmp-6.2.1 + mpfr-4.1.0 + mpc-1.2.1 built OK -> /usr/lib/gcc-math (libgmp.a/libmpfr.a/libmpc.a)" >&2
