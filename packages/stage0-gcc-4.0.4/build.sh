#!/usr/bin/env bash
# stage0-gcc-4.0.4: builds gcc-core 4.0.4 (cc1, xgcc, cpp, libgcc.a) from gcc-core-4.0.4.tar.bz2
# with tcc-musl2 as CC, linked statically against the musl sysroot at /usr/lib/musl-bedrock,
# installed under /usr into $OUTPUT_DIR. as/ranlib come from stage0-binutils-2.30 on PATH.
# The tarball ships every generated file; nothing is regenerated (no autotools/bison/flex/perl here).
# phases: unpack, CC wrapper, source seds, mtime guard, configure, build, install, pin gate
set -ex
VERSION="${MINIMAL_ARG_VERSION:-4.0.4}"
TARBALL="gcc-core-${VERSION}.tar.bz2"
SRC="gcc-${VERSION}"               # tarball is gcc-core-*, extracted dir is gcc-*
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"          # build=host=target; the shipped config.sub knows this triplet
TCC=/usr/bin/tcc-musl2             # CC backend and archiver

# --- unpack ---
# --no-same-owner: the sandbox user namespace cannot chown to the archived uid.
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# --- CC wrapper over tcc-musl2 ---
# Compile (-c/-S/-E) passes straight through. Link puts the crt files explicitly and libc.a on both
# sides of libtcc1.a: libtcc1 references abort() in libc, and a single -lc leaves that cycle
# unresolved on a static link.
cat > "${BUILDROOT}/musl-cc" <<'WRAP'
#!/bin/sh
# Build against the single-writer musl sysroot, not /usr: the sandbox rootfs merges a glibc whose
# headers and libc.a can shadow musl's. -nostdinc plus explicit crt/libc from $MB make every compile
# and link deterministic. /usr/lib/tcc/libtcc1.a has a single writer.
MB=/usr/lib/musl-bedrock
for a in "$@"; do case "$a" in -c|-S|-E) exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" "$@" ;; esac; done
# -L "$MB/lib": gcc links -lm; musl's libm.a there is an empty stub, and without this tcc's default
# search would find glibc's /usr/lib/libm.so instead.
exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" -nostdlib -static -L "$MB/lib" \
  "$MB/lib/crt1.o" "$MB/lib/crti.o" "$@" \
  "$MB/lib/libc.a" /usr/lib/tcc/libtcc1.a "$MB/lib/libc.a" "$MB/lib/crtn.o"
WRAP
chmod +x "${BUILDROOT}/musl-cc"
MUSLCC="${BUILDROOT}/musl-cc"

# --- source seds (from live-bootstrap steps/gcc-4.0.4/pass1.sh) ---
# tcc rejects the zero-length array ix86_attribute_table[]; gcc/config/i386 is compiled for x86_64 too.
sed -i 's/ix86_attribute_table\[\]/ix86_attribute_table\[10\]/' gcc/config/i386/i386.c
# musl: struct siginfo -> siginfo_t in the unwinder.
sed -i 's/struct siginfo/siginfo_t/' gcc/config/i386/linux-unwind.h
# The C_alloca -> alloca sed is applied after configure, below.

# --- mtime guard ---
# The tarball ships both generated outputs and their .y/.l/.in sources. If a source is newer, make
# calls the absent bison/flex/autoconf and the build dies. Baseline every file old, then bump every
# generated file to one newer mtime in a single touch call.
find . -exec touch -d '2001-01-01 00:00:00' {} +
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' \
                  -o -name 'aclocal.m4' -o -name 'Makefile.in' \
                  -o -name '*.info' -o -name '*.gmo' \) -print) \
      gcc/c-parse.y gcc/c-parse.c gcc/c-parse.h \
      gcc/gengtype-yacc.c gcc/gengtype-yacc.h gcc/gengtype-lex.c \
      intl/plural.c libcpp/ucnid.h fixincludes/fixincl.x

# Stubs for the regeneration tools: a generated file the guard missed fails loudly by tool name
# instead of being clobbered via `$(TOOL) ... > $@`. makeinfo/msgfmt are covered by MAKEINFO=true
# and --disable-nls.
STUBS="${BUILDROOT}/regen-stubs"
mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl \
         autoconf autoheader autom4te aclocal automake autoreconf libtoolize \
         autoconf-2.61 autoheader-2.61 autom4te-2.61 aclocal-1.9 aclocal-1.10 automake-1.10 autoreconf-2.61; do
  cat > "${STUBS}/${t}" <<STUB
#!/bin/sh
echo "gcc-4.0.4 MODEL-B GUARD: '${t}' was invoked (\$*) -> a generated file is being regenerated. The mtime" >&2
echo "guard missed it; add it to the touch list in build.sh. Model-B must NOT regen (no autotools/" >&2
echo "bison/flex/perl available). Failing loudly rather than silently clobbering a shipped file." >&2
exit 1
STUB
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# --- configure: out of tree, per subdir, in dependency order ---
#   AR="tcc-musl2 -ar" RANLIB=true: tcc -ar indexes its archives itself (binutils ar/ranlib on PATH
#     would also work as AR=ar RANLIB=ranlib).
#   -D HAVE_ALLOCA_H: musl ships alloca.h.
#   --disable-nls: removes the intl/gettext regeneration surface.
#   --disable-multilib: gcc-4.0.4 on x86_64-linux defaults to also building a 32-bit libgcc, which
#     needs a 32-bit crt and assembler target this toolchain does not have.
mkdir build
cd build
for dir in libiberty libcpp gcc; do
  mkdir "${dir}"
  ( cd "${dir}" && \
    CC="${MUSLCC}" AR="${TCC} -ar" RANLIB=true \
    CFLAGS="-D HAVE_ALLOCA_H" \
      "../../${dir}/configure" \
        --prefix="${PREFIX}" \
        --libdir="${LIBDIR}" \
        --build="${TARGET}" \
        --host="${TARGET}" \
        --target="${TARGET}" \
        --disable-shared \
        --disable-multilib \
        --disable-nls \
        --program-transform-name= )
done
cd ..

# pass1.sh applies the C_alloca sed after configure:
sed -i 's/C_alloca/alloca/g' libiberty/alloca.c
sed -i 's/C_alloca/alloca/g' include/libiberty.h

# --- build ---
#   LIBGCC2_INCLUDES: libgcc2.c takes the musl sysroot headers, not the merged /usr/include.
#   STMP_FIXINC= : no fixincludes stamp (musl headers need no fixing).
#   MAKEINFO=true : skip texinfo.
#   -j1: the cc1 link under tcc is the peak-memory step.
ln -s . "build/build-${TARGET}"
mkdir -p build/gcc/include
ln -s ../../../gcc/gsyslimits.h build/gcc/include/syslimits.h
# libgcc's build depends on stmp-fixinc -> fixincludes/fixinc.sh, but the fixincludes dir is never
# configured (it exists to patch glibc headers). A no-op fixinc.sh satisfies the stamp and leaves
# include-fixed empty. build/build-<tgt>/fixincludes resolves through the `ln -s .` symlink above.
mkdir -p build/fixincludes
printf '#!/bin/sh\nexit 0\n' > build/fixincludes/fixinc.sh
chmod +x build/fixincludes/fixinc.sh
# xgcc compiles crtbegin/crtend/libgcc with its own baked search path (/usr/include, /usr/lib), not
# the wrapper. CPATH/LIBRARY_PATH prepend the musl sysroot so it resolves musl's headers and crt.
export CPATH="/usr/lib/musl-bedrock/include"
export LIBRARY_PATH="/usr/lib/musl-bedrock/lib"
for dir in libiberty libcpp gcc; do
  make -j1 -C "build/${dir}" \
    LIBGCC2_INCLUDES="-I/usr/lib/musl-bedrock/include" \
    STMP_FIXINC= MAKEINFO=true
done

# --- install: DESTDIR redirects writes off the read-only /usr into $OUTPUT_DIR ---
mkdir -p "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/install-tools/include"
make -j1 -C build/gcc install STMP_FIXINC= MAKEINFO=true DESTDIR="${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/include"
rm -f "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/include/syslimits.h"
cp gcc/gsyslimits.h "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/include/syslimits.h"

# --- pin gate: disabled until stage0.answers carries the captured shas ---
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
