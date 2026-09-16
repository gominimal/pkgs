#!/bin/sh
# stage0-musl-1.1.24: build musl 1.1.24 with tcc-0.9.27 and install libc.a, crt*.o and headers
# under $OUTPUT_DIR. Derived from live-bootstrap steps/musl-1.1.24/pass1.sh, built --host=x86_64.
# CC=tcc compiles every .c and assembles every .s (no binutils yet); AR="tcc -ar", RANLIB=true.
# phases: unpack, patch, source pruning, configure, tcc retry wrapper, make, sha256 gate, sysroot copy
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"
# Local files (build.sh, *.patch, stage0.answers) sit in the build root.
BUILDROOT="$(pwd)"

# --- unpack (Source is extract=false) ---
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

# mes-libc/tcc cannot regenerate the ctype tables or build iconv, and tcc has no _Complex;
# drop the consumers as live-bootstrap pass1 does (pairs with disable_ctype_headers.patch).
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c
rm -rf src/complex

# tcc-0.9.27's assembler cannot handle musl's x86_64 SSE math/fenv .s files (stmxcsr/ldmxcsr and
# others) or sigsetjmp.s; all have C fallbacks, so remove the asm and let musl build the C versions.
# setjmp.s and longjmp.s assemble fine and have no C fallback, so they stay.
rm -f src/math/x86_64/*.s src/fenv/x86_64/*.s src/signal/x86_64/sigsetjmp.s

# live-bootstrap pass1's `mkdir -p /dev` and `rm /dev/null` are skipped: the sandbox provides
# /dev/null and / is read-only.

# --- configure: static only; prefix /usr, redirected via DESTDIR at install ---
CC=tcc ./configure \
    --host=x86_64 \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib \
    --includedir=/usr/include

# --- compile + install ---
# CROSS_COMPILE= blanks the x86_64- prefix configure would add to AR/RANLIB. CFLAGS=-DSYSCALL_NO_TLS
# matches live-bootstrap (errno without TLS). No -O/-march: tcc rejects them.
# tcc-0.9.27 runs on the mes-libc, whose allocator occasionally crashes on a per-file compile;
# output is byte-identical on success, so re-run a compile that dies by signal. The wrapper
# calls the real tcc by absolute path to avoid recursion.
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

# CC is the retry wrapper; AR stays the real `tcc -ar` (archiving does not compile). configure
# already ran with the real tcc, so config.mak's CC is overridden for the build only.
make CROSS_COMPILE= CC="${BUILDROOT}/tcc-retry" AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w"
make CROSS_COMPILE= CC="${BUILDROOT}/tcc-retry" AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w" \
     DESTDIR="${OUTPUT_DIR}" install

# --- byte-identity gate: paths in stage0.answers are relative to $OUTPUT_DIR; a mismatch aborts (set -e) ---
cd "${OUTPUT_DIR}"
sha256sum -c "${BUILDROOT}/stage0.answers"

# --- sysroot copy ---
# In consumer sandboxes the merged /usr/{include,lib} is also written by glibc and the rootfs
# overlay is first-writer-wins, so consumers compile and link -nostdinc/-nostdlib against this
# versioned copy, which no other package writes. Copied after the gate so it holds the checked bytes.
SR="${OUTPUT_DIR}/usr/lib/musl-bedrock-1.1.24"
mkdir -p "$SR/lib"
cp -a "${OUTPUT_DIR}/usr/include" "$SR/include"
cp -a "${OUTPUT_DIR}"/usr/lib/*.o "${OUTPUT_DIR}"/usr/lib/*.a "$SR/lib/"
