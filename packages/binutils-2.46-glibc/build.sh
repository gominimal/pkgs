#!/bin/sh
# binutils-2.46-glibc: builds binutils 2.46.0 (as, ld, ar, nm, objcopy, objdump, ranlib, readelf,
# strip, shared libbfd/libopcodes) from binutils-2.46.0.tar.xz with stage0-gcc-15.2.0 as CC,
# glibc-dynamic against the glibc-2.42 sysroot at /usr/lib/glibc-bedrock-2.42, as/ld from
# stage0-binutils-2.41, with the production binutils configure flags. Installed under /usr into
# $OUTPUT_DIR. On aarch64 the prebuilt artifact from build.ncl's Arm64 Source (binutils 2.41) is
# extracted instead of building.
# phases: arm extract, clean state, preconditions, libc.so fix, unpack, CC/CXX wrappers, mtime guard, configure, build, install, triplet symlinks, smoke gate
if [ "$(uname -m)" = "aarch64" ]; then
  set -ex
  ART=$(ls stage0-binutils-*-aarch64.tar.zst /build/stage0-binutils-*-aarch64.tar.zst 2>/dev/null | head -1)
  [ -n "$ART" ] || { echo "FATAL: arm artifact not hydrated (stage0-binutils-*-aarch64.tar.zst)" >&2; exit 1; }
  mkdir -p "$OUTPUT_DIR"
  tar --zstd --no-same-owner -xf "$ART" -C "$OUTPUT_DIR"
  LD=$(find "$OUTPUT_DIR" -name ld -type f -path '*/bin/*' | head -1)
  [ -n "$LD" ] || { echo "FATAL: ld missing after extract" >&2; exit 1; }
  exit 0
fi

# --- clean state: the build directory may persist between runs ---
# Start from an empty $OUTPUT_DIR and drop every top-level directory (derived build/source trees);
# inputs re-hydrate as top-level files. A stale partial install would otherwise poison the gate.
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"
for _d in ./*/; do [ -d "$_d" ] && find "$_d" -delete; done
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.46.0}"
SRC="binutils-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
T="x86_64-linux-gnu"            # build=host=target
SR=/usr/lib/glibc-bedrock-2.42  # glibc-2.42 sysroot (libc.so + crt*.o + headers + kernel UAPI)
LOADER="$SR/lib/ld-linux-x86-64.so.2"

command -v gcc >/dev/null 2>&1 || { echo "binutils-glibc: gcc (gcc-15.2.0) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "binutils-glibc: as (binutils-2.41) not on PATH — gcc needs it to assemble" >&2; exit 1; }
[ -e "$SR/lib/libc.so" ]   || { echo "binutils-glibc: glibc sysroot missing at $SR (libc.so)" >&2; exit 1; }
[ -f "$SR/lib/crt1.o" ]    || { echo "binutils-glibc: glibc startfiles missing at $SR/lib (crt1.o)" >&2; exit 1; }
[ -e "$LOADER" ]           || { echo "binutils-glibc: glibc dynamic loader missing at $LOADER" >&2; exit 1; }

# --- libc.so linker-script fix ---
# The sysroot's libc.so is a linker script whose GROUP() paths may carry the glibc build's staging
# prefix (/build/output/...), which dangles here and makes ld fail to resolve -lc. Regenerate a
# corrected copy in a directory ld searches first; the rewrite is prefix-agnostic.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "binutils-glibc: libc.so fixup failed" >&2; exit 1; }

# --- unpack (--no-same-owner: the sandbox user namespace cannot chown to the archived uid) ---
tar --no-same-owner -xf "${SRC}.tar.xz"

# --- CC + CXX wrappers: the host gcc onto the glibc sysroot (dynamic, no -static) ---
# -nostdinc with the gcc freestanding headers plus the sysroot headers (kernel UAPI included) on
# compile; -B/-L the sysroot on link, so nothing is taken from the merged /usr.
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
# --dynamic-linker: the sandbox has no /lib64 (gcc's default interp path); bake the sysroot loader
# so configure's conftests and every produced binary can exec in-sandbox.
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -L "${FIXLIB}" -B "\$SR/lib" -L "\$SR/lib" -Wl,--dynamic-linker="\$SR/lib/ld-linux-x86-64.so.2" -Wl,-rpath,"\$SR/lib" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# CXX only serves the top-level configure's AC_PROG_CXX probe (a headerless int main): gold and
# gprofng, the C++ subdirs, are disabled, so -nostdinc is safe.
GXX_GI="$(g++ -print-file-name=include 2>/dev/null || echo "${GI}")"
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
GI="${GXX_GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/g++ -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/g++ -nostdinc -isystem "\$GI" -isystem "\$SR/include" -L "${FIXLIB}" -B "\$SR/lib" -L "\$SR/lib" -Wl,--dynamic-linker="\$SR/lib/ld-linux-x86-64.so.2" -Wl,-rpath,"\$SR/lib" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GXXCC="${BUILDROOT}/gcc-cxx"

cd "${SRC}"

# --- mtime guard + regeneration-tool stubs ---
# 2.46 ships every generated file (configure, Makefile.in, the bison/flex parsers, opcodes/i386-tbl.h,
# .info and man pages). Baseline everything old, then bump every output newer than any .y/.l/.pod
# source so make never invokes the absent bison/flex/perl/pod2man; the stubs make a missed file fail
# by name.
find . -exec touch -d '2001-01-01 00:00:00' {} +
find . \( -name '*.c' -o -name '*.h' -o -name '*.info' -o -name 'configure' \
          -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
          -o -name 'Makefile.in' -o -name '*.1' -o -name '*.man' -o -name '*.pod' \) \
     -exec touch -d '2020-01-01 00:00:00' {} +
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
# flex/lex are not stubbed: AC_PROG_LEX runs the lexer and checks its output, so a failing stub
# aborts configure ("cannot find output from flex"). With no flex on PATH autoconf sets LEX=: and
# skips the check; the shipped ldlex.c/deffilep.c are mtime-guarded. AC_PROG_YACC only sets $YACC,
# so bison/yacc stay stubbed.
for t in bison yacc m4 gperf perl pod2man help2man texi2pod \
         autoconf autoheader autom4te aclocal automake autoreconf libtoolize makeinfo; do
  printf '#!/bin/sh\necho "binutils-glibc MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; mtime guard missed it, add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# --- configure: top level, out of tree, production binutils flags ---
#   --enable-ld=default: ld.bfd is the default ld.
#   --enable-plugins: dlopen linker plugins (glibc has a real dlopen).
#   --enable-shared: libbfd.so/libopcodes.so.
#   --enable-new-dtags --enable-default-hash-style=gnu --enable-deterministic-archives: production ABI/determinism.
#   --disable-gold --disable-gprofng: the C++ subdirs would link the host's musl-built libstdc++.a
#     into a glibc binary. ld.bfd is the default ld regardless, so consumers are unaffected.
#   No --with-system-zlib: the bundled zlib is used (affects compressed debug sections only).
# HOSTCFLAGS are the production determinism flags; the wrapper layers -nostdinc/-isystem on top.
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
HOSTCFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
CC="${GCCCC}" CXX="${GXXCC}" AR=ar RANLIB=ranlib CFLAGS="${HOSTCFLAGS}" CXXFLAGS="${HOSTCFLAGS}" \
  "../${SRC}/configure" \
    --prefix="${PREFIX}" --libdir="${LIBDIR}" \
    --sysconfdir=/etc \
    --build="${T}" --host="${T}" --target="${T}" \
    --enable-ld=default \
    --enable-plugins \
    --enable-shared \
    --disable-werror --disable-nls \
    --enable-new-dtags \
    --enable-default-hash-style=gnu \
    --enable-deterministic-archives \
    --disable-gold --disable-gprofng \
    --disable-multilib \
    MAKEINFO=true

# --- build + install: production tooldir=/usr and install-strip ---
# --prefix stays /usr because as/ld bake their prefix; DESTDIR redirects the install into $OUTPUT_DIR.
make -j"$(nproc)" tooldir=/usr MAKEINFO=true
make -j"$(nproc)" tooldir=/usr MAKEINFO=true DESTDIR="${OUTPUT_DIR}" install-strip

# Drop libtool archives: they bake the dead build path in dependency_libs.
rm -f "${OUTPUT_DIR}${LIBDIR}"/*.la 2>/dev/null || true

# --- triplet symlinks ---
# Add relative x86_64-linux-gnu-<tool> aliases for target-prefixed lookups. Relative so the target
# does not dangle inside $OUTPUT_DIR at staging time.
cd "${OUTPUT_DIR}/usr/bin"
for f in *; do
  case "$f" in x86_64-linux-gnu-*) continue ;; esac
  ln -sf "$f" "x86_64-linux-gnu-$f"
done

# --- smoke gate: the new as+ld must assemble and link a glibc-dynamic executable that runs ---
# The host gcc is the driver; -B $OUTPUT_DIR/usr/bin forces the fresh as/ld and -B/-L $SR/lib the
# glibc sysroot. The exe runs via an explicit loader invocation (no /lib64 in the sandbox).
NAS="${OUTPUT_DIR}/usr/bin"
GATE="${BUILDROOT}/asgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
printf 'int main(void){ return 42; }\n' > "${GATE}/t.c"
set +e
# LD_LIBRARY_PATH: the fresh as/ld link libbfd/libopcodes/libsframe dynamically from
# $OUTPUT_DIR/usr/lib (their RUNPATH is the not-yet-installed /usr/lib).
# -L $FIXLIB: this direct gcc call bypasses the wrapper, so it needs the corrected libc.so too.
LD_LIBRARY_PATH="${OUTPUT_DIR}/usr/lib:${SR}/lib" \
/usr/bin/gcc -nostdinc -isystem "${GI}" -isystem "${SR}/include" \
  -B "${NAS}" -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" \
  "${GATE}/t.c" -o "${GATE}/t" 2>"${GATE}/err"
crc=$?
rrc=1
if [ "${crc}" -eq 0 ]; then
  "${LOADER}" --library-path "${SR}/lib" "${GATE}/t"; rrc=$?
fi
set -e
if [ "${crc}" -eq 0 ] && [ "${rrc}" -eq 42 ]; then
  echo "AS-LD-GATE: PASS (new glibc-linked as+ld assembled+linked a running glibc-dynamic exe; exit=${rrc})" >&2
else
  echo "AS-LD-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -8 "${GATE}/err" >&2 || true
  exit 1
fi

# No pin gate: a different compiler than the prebuilt built this, so byte parity with the prebuilt
# is not expected. --enable-deterministic-archives, --build-id=none and -ffile-prefix-map keep the
# artifact reproducible. See stage0.answers.
