#!/bin/sh
# stage0-gmp-mpfr-mpc: builds gmp-6.2.1, mpfr-4.1.0 and mpc-1.2.1 as static libs with stage0-gcc-4.0.4
# as CC, linked against the musl-1.2.5 sysroot, published to /usr/lib/gcc-math/{lib,include} in
# $OUTPUT_DIR for gcc's --with-gmp/--with-mpfr/--with-mpc. Build order: gmp, mpfr, mpc.
set -ex
BUILDROOT="$(pwd)"
STAGE="${BUILDROOT}/gcc-math"            # writable build-local prefix so libtool .la cross-references
                                         #   resolve (mpc's libmpfr.la -> libgmp.la); a DESTDIR install
                                         #   would leave .la files pointing at the read-only /usr.
FINAL="${OUTPUT_DIR}/usr/lib/gcc-math"   # published tree

# --no-same-owner: the sandbox user namespace cannot chown to the archived uid.
untar() { tar --no-same-owner -xf "$1"; }

command -v gcc >/dev/null 2>&1 || { echo "gmp-mpfr-mpc: gcc (gcc-4.0.4) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "gmp-mpfr-mpc: as (binutils-2.30) not on PATH" >&2; exit 1; }

# --- CC wrapper: gcc-4.0.4 onto the musl-1.2.5 sysroot ---
# gmp/mpfr/mpc include libc headers, so the sysroot include dir is added on compile; -B/-L the
# sysroot and -static on link.
SR=/usr/lib/musl-bedrock-1.2.5
GI="$(gcc -print-file-name=include)"
[ -d "$GI" ] || { echo "gmp-mpfr-mpc: gcc freestanding include dir not found ('$GI')" >&2; exit 1; }
[ -f "$SR/lib/libc.a" ] || { echo "gmp-mpfr-mpc: musl-1.2.5 sysroot missing at $SR" >&2; exit 1; }
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# Keep the shipped configure; touch the generated files newest so make never invokes the absent
# autoreconf/automake/aclocal on an mtime inversion.
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

# --- gmp: --disable-assembly => generic C mpn (no hand-written x86_64 asm for gcc-4.0.4/binutils-2.30) ---
untar gmp-6.2.1.tar.xz
build_one gmp-6.2.1 --disable-assembly

# --- mpfr: needs gmp ---
untar mpfr-4.1.0.tar.xz
build_one mpfr-4.1.0 --with-gmp="${STAGE}"

# --- mpc: needs gmp + mpfr ---
untar mpc-1.2.1.tar.gz
build_one mpc-1.2.1 --with-gmp="${STAGE}" --with-mpfr="${STAGE}"

# --- publish staging -> output. Drop the .la files: they bake the build-local $STAGE path, and gcc
#     links the static .a directly via --with-gmp/mpfr/mpc. ---
mkdir -p "${FINAL}"
cp -a "${STAGE}/lib" "${STAGE}/include" "${FINAL}/"
rm -f "${FINAL}/lib"/*.la

# --- sanity gate: the three static libs and their headers must exist in the output ---
for f in lib/libgmp.a lib/libmpfr.a lib/libmpc.a include/gmp.h include/mpfr.h include/mpc.h; do
  [ -f "${FINAL}/${f}" ] || { echo "gmp-mpfr-mpc FAIL: missing ${FINAL}/${f}" >&2; exit 1; }
done
echo "gmp-mpfr-mpc: gmp-6.2.1 + mpfr-4.1.0 + mpc-1.2.1 built OK -> /usr/lib/gcc-math (libgmp.a/libmpfr.a/libmpc.a)" >&2
