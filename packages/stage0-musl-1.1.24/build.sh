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
patch -Np1 -i "${BUILDROOT}/amd64-va-list.patch"          # amd64: define __builtin_va_list (tcc-0.9.27 segfaults on it) via tcc's SysV __va_list_struct

# meslibc/tcc cannot regenerate the ctype tables or iconv, and tcc has no _Complex — drop the
# consumers exactly as live-bootstrap pass1 does (these are the `rm`s that pair with
# disable_ctype_headers.patch):
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c
rm -rf src/complex

# [amd64 asm-rm 2026-06-26] tcc-0.9.27's integrated assembler can't handle musl's x86_64 SSE math/fenv/
# setjmp .s (unknown opcodes e.g. stmxcsr/ldmxcsr, or SIGSEGV on others). Portable C fallbacks exist for
# all of them (sqrt.c/fabs.c/expl.c/lrint.c/.../sigsetjmp.c), so remove the asm and let musl build the C
# versions — correctness over speed, exactly right for a bootstrap libc. (live-bootstrap's i386 asm
# assembles under their tcc; the x86_64 asm is amd64-net-new, Tier-3. Confirmed via the local tcc harness:
# every C fallback compiles.)
# NB: core setjmp/x86_64/setjmp.s + longjmp.s ASSEMBLE FINE and have NO C fallback — KEEP them. Only
# sigsetjmp.s (signal) fails and has a C fallback (sigsetjmp.c -> calls the kept setjmp.s).
rm -f src/math/x86_64/*.s src/fenv/x86_64/*.s src/signal/x86_64/sigsetjmp.s

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
# [amd64 arena-lottery 2026-06-26] tcc-0.9.27 runs on the mes-libc whose allocator layout makes it
# SIGSEGV ~randomly on some per-file compiles in the CS sandbox (the arena lottery — NONdeterministic
# WHETHER it crashes, but the .o is byte-IDENTICAL on success; cf. R2/R3 lottery). The full 1900-file
# `make` therefore stops at a random file (locally 0/10, in CS it hit src/env/__init_tls.o). R4 is the
# LAST rung on mes-libc (R5+ runs on the musl we are building here), so a per-file RETRY wrapper cures it
# cleanly: re-run the exact compile on signal-death until it lands. Output determinism preserves the
# byte-identity seal. Wrap the REAL tcc (resolved now) under a different name so there is no recursion.
REALTCC="$(command -v tcc)"
cat > "${BUILDROOT}/tcc-retry" <<WRAP
#!/bin/sh
i=0
while [ \$i -lt 20 ]; do
  "${REALTCC}" "\$@"; rc=\$?
  [ \$rc -le 128 ] && exit \$rc
  i=\$((i+1)); echo "tcc-retry: signal-death rc=\$rc, attempt \$i/20 -> \$*" >&2
done
exit \$rc
WRAP
chmod 755 "${BUILDROOT}/tcc-retry"

# CC = the retry wrapper for the compile (cures the lottery); AR stays the real `tcc -ar` (archiving
# does not compile, so it does not lottery).  configure already ran with the real tcc (it handles its
# own probe segfaults), so config.mak's CC is overridden here for the build only.
make CROSS_COMPILE= CC="${BUILDROOT}/tcc-retry" AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w"
make CROSS_COMPILE= CC="${BUILDROOT}/tcc-retry" AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w" \
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
