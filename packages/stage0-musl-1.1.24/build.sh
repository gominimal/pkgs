#!/bin/sh
# build.sh — R4 (stage0-musl-1.1.24) driver, DERIVED from live-bootstrap
# steps/musl-1.1.24/pass1.sh (master @ 2026-06).  This is the FIRST bedrock rung driven by the
# SHELL instead of the attested kaem: musl builds via `./configure` + `make`, neither of which
# runs under kaem.  See build.ncl for the full rationale (esp. the amd64-vs-i386 patch analysis
# and why R4 is the bash re-entry boundary).
#
# WHAT BUILDS MUSL: CC=tcc -> R3's tcc-0.9.27 compiles every .c and assembles every .s with its
# INTEGRATED assembler (no binutils `as` yet); AR="tcc -ar" archives (no binutils `ar` yet);
# RANLIB=true is a no-op.  musl is freestanding (-nostdinc, its own headers) and is only -c/-ar'd
# (never linked into an executable), so tcc's -static linker / R2's PLT defect are not exercised.
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"
# Local files (build.sh, *.patch, stage0.answers) sit in the build root; remember it before cd.
BUILDROOT="$(pwd)"

# --- unpack (Source is extract=false; we tar here per the bash-build convention) ---
tar -xf "${SRC}.tar.gz"
cd "${SRC}"

# --- patches: ONLY the four ARCH-NEUTRAL live-bootstrap patches (the i386-specific ones do not
#     apply to the x86_64 build — see build.ncl).  Real `patch` is used (we are in the shell now;
#     R0-R3's simple-patch cannot apply multi-hunk unified diffs). ---
patch -Np1 -i "${BUILDROOT}/makefile.patch"               # tcc -ar can't make empty archives -> touch
patch -Np1 -i "${BUILDROOT}/madvise_preserve_errno.patch" # preserve errno across __madvise
patch -Np1 -i "${BUILDROOT}/avoid_sys_clone.patch"        # posix_spawn: fork() instead of __clone
patch -Np1 -i "${BUILDROOT}/disable_ctype_headers.patch"  # drop iswalpha/… decls (no table regen)
patch -Np1 -i "${BUILDROOT}/skip-pic-crt.patch"           # amd64: skip Scrt1.o/rcrt1.o (tcc segfaults on -fPIC %rip crt)
patch -Np1 -i "${BUILDROOT}/drop-dynamic-crt.patch"       # amd64: drop _DYNAMIC lea from crt_arch.h (tcc asm segfault on weak+hidden %rip)

# meslibc/tcc cannot regenerate the ctype tables or iconv, and tcc has no _Complex — drop the
# consumers exactly as live-bootstrap pass1 does (these are the `rm`s that pair with
# disable_ctype_headers.patch):
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c
rm -rf src/complex

# NOTE: live-bootstrap pass1 does `mkdir -p /dev` + later `rm /dev/null`; that was for its early
# environment which lacked /dev/null.  Our CS builder already provides /dev/null and / is mounted
# READ-ONLY (§D), so we deliberately skip both.

# --- configure: CC=tcc (R3); --host=x86_64 is THE amd64 adaptation (live-bootstrap uses i386).
#     static only; install layout baked to /usr, physically redirected via DESTDIR below. ---
CC=tcc ./configure \
    --host=x86_64 \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib \
    --includedir=/usr/include

# --- compile + install.  CROSS_COMPILE= blanks the x86_64- prefix configure would add to AR/RANLIB;
#     AR="tcc -ar" / RANLIB=true because no binutils exists yet; CFLAGS=-DSYSCALL_NO_TLS matches
#     live-bootstrap (errno without TLS in the early/tcc context).  NO -march/-O/gcc-isms (tcc would
#     reject them); musl's configure supplies its own CFLAGS. ---
make CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS"
make CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" \
     DESTDIR="${OUTPUT_DIR}" install

###########################################################################
# BYTE-IDENTITY GATE.  amd64 has NO upstream fixed point (live-bootstrap ships only an i386 musl),
# so these are RECORD-AT-PIN-TIME: captured after the first green amd64 CS build, pinned into
# stage0.answers, then this `-c` is re-enabled to SEAL R4 as an L4 fixed point (cf. R2/R3).
# Paths in stage0.answers are RELATIVE to $OUTPUT_DIR, so we check from there.
# FIRST-BUILD NOTE: stage0.answers ships with ONLY commented lines, so for the CAPTURE run this
# `-c` MUST stay disabled (it would fail "no properly formatted checksum lines").
###########################################################################
cd "${OUTPUT_DIR}"
# sha256sum -c "${BUILDROOT}/stage0.answers"   # re-enable after the 6 amd64 shas are pinned

###########################################################################
# §D STAGING: every output went to DESTDIR=$OUTPUT_DIR, so build.ncl's `outputs` globs already
# match the on-disk tree:
#   usr/lib/libc.a · usr/lib/*.o (crt1/crti/crtn/Scrt1/rcrt1) · usr/lib/*.a (incl. empty stubs)
#   usr/include/**  (musl headers)
###########################################################################
