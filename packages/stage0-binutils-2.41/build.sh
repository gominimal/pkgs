#!/usr/bin/env bash
# stage0-binutils-2.41: builds binutils 2.41 (as, ld, ar, nm, objcopy, objdump, ranlib, readelf,
# strip, libbfd.a, libopcodes.a) from binutils-2.41.tar.xz with stage0-gcc-4.7.4 as CC, linked
# statically against the musl-1.2.5 sysroot, installed under /usr into $OUTPUT_DIR. gcc shells out to
# as/ld/ranlib, so stage0-binutils-2.30 must be on PATH. The tarball ships every generated file.
# phases: preconditions, unpack, CC/CXX wrappers, mtime guard, configure, build, install, triplet symlinks, smoke gate, pin gate
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.41}"
SRC="binutils-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
T="x86_64-linux-gnu"            # build=host=target
SR=/usr/lib/musl-bedrock-1.2.5  # musl-1.2.5 sysroot (libc.a + crt*.o + headers)

command -v gcc >/dev/null 2>&1 || { echo "binutils-2.41: gcc (gcc-4.7.4) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "binutils-2.41: as (binutils-2.30) not on PATH — gcc needs it to assemble" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "binutils-2.41: musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }

# --- unpack ---
# --no-same-owner: the sandbox user namespace cannot chown to the archived uid.
tar --no-same-owner -xf "${SRC}.tar.xz"

# --- CC + CXX wrappers: gcc-4.7.4 onto the musl-1.2.5 sysroot ---
# -nostdinc with the gcc freestanding headers plus the sysroot headers on compile; -B/-L the sysroot
# and -static on link, so no header or libc is taken from the merged /usr.
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# CXX only serves the top-level configure's AC_PROG_CXX probe (a headerless int main): gold and
# gprofng, the C++ subdirs, are disabled, so -nostdinc is safe. If a C++ subdir is ever enabled this
# wrapper needs the libstdc++ include dirs.
GXX_GI="$(g++ -print-file-name=include 2>/dev/null || echo "${GI}")"
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
GI="${GXX_GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/g++ -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/g++ -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GXXCC="${BUILDROOT}/gcc-cxx"

cd "${SRC}"

# --- mtime guard + regeneration-tool stubs ---
# 2.41 ships every generated file (configure, Makefile.in, the bison/flex parsers, opcodes/i386-tbl.h,
# .info and man pages). Baseline everything old, then bump every output newer than any .y/.l/.pod
# source so make never invokes the absent bison/flex/perl/pod2man; the stubs make a missed file fail
# by name.
find . -exec touch -d '2001-01-01 00:00:00' {} +
# Deliberately broad: every .c/.h is an output and must be at least as new as any source. No .o
# exists yet, so compilation is unaffected.
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
  printf '#!/bin/sh\necho "binutils-2.41 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; mtime guard missed it, add it to the touch list (or Model-A regen is required)." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# --- configure: top level, out of tree ---
#   --disable-gold --disable-gprofng: the C++ and bison-heavy components; not needed on static musl.
#   --disable-plugins: no dlopen linker plugins (static musl's dlopen is a stub).
#   --enable-install-libbfd: libbfd.a/libopcodes.a and bfd.h land in /usr so the output globs match.
#   --with-sysroot= : empty, so ld bakes no sysroot prefix.
#   MAKEINFO=true: skip texinfo.
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
# gcc-4.7 defaults to -std=gnu89, where a C99 for-loop declaration is a hard error; the newer subdirs
# (libctf, libsframe) use them, so force -std=gnu99. -fgnu89-inline keeps GNU89 inline semantics so
# the older bfd/opcodes headers do not lose their out-of-line copies. CFLAGS at top-level configure
# propagates to every host subdir. Fallback if libctf still fails to compile: --disable-libctf.
HOSTCFLAGS="-g -O2 -std=gnu99 -fgnu89-inline"
CC="${GCCCC}" CXX="${GXXCC}" AR=ar RANLIB=ranlib CFLAGS="${HOSTCFLAGS}" \
  "../${SRC}/configure" \
    --prefix="${PREFIX}" --libdir="${LIBDIR}" \
    --build="${T}" --host="${T}" --target="${T}" \
    --program-prefix="" \
    --disable-shared --disable-nls --disable-werror \
    --disable-gold --disable-gprofng --disable-plugins \
    --enable-deterministic-archives --enable-64-bit-bfd \
    --enable-install-libbfd \
    --with-sysroot= \
    MAKEINFO=true

# --- build + install ---
# --prefix stays /usr because as/ld bake their prefix; DESTDIR redirects the install into $OUTPUT_DIR.
make -j1 MAKEINFO=true
make -j1 MAKEINFO=true DESTDIR="${OUTPUT_DIR}" install

# Drop libtool archives: they bake the dead build path in dependency_libs; downstream links the .a
# directly.
rm -f "${OUTPUT_DIR}${LIBDIR}"/*.la

# --- triplet symlinks ---
# A native binutils installs plain names; add relative x86_64-linux-gnu-<tool> aliases for
# target-prefixed lookups. Relative so the target does not dangle inside $OUTPUT_DIR at staging time;
# -f for idempotence; skip already-prefixed names so the glob cannot nest.
cd "${OUTPUT_DIR}/usr/bin"
for f in *; do
  case "$f" in x86_64-linux-gnu-*) continue ;; esac
  ln -sf "$f" "x86_64-linux-gnu-$f"
done

# --- smoke gate: the new as+ld must assemble and link a static musl executable that runs ---
# gcc-4.7.4 is the driver; -B $OUTPUT_DIR/usr/bin forces the fresh as/ld.
NAS="${OUTPUT_DIR}/usr/bin"
GATE="${BUILDROOT}/asgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
printf 'int main(void){ return 42; }\n' > "${GATE}/t.c"
set +e
/usr/bin/gcc -nostdinc -isystem "${GI}" -isystem "${SR}/include" \
  -B "${NAS}" -B "${SR}/lib" -L "${SR}/lib" -static \
  "${GATE}/t.c" -o "${GATE}/t" 2>"${GATE}/err"
crc=$?
"${GATE}/t"; rrc=$?
set -e
if [ "${crc}" -eq 0 ] && [ "${rrc}" -eq 42 ]; then
  echo "AS-LD-GATE: PASS (new as+ld assembled+linked a running static-musl exe; exit=${rrc})" >&2
else
  echo "AS-LD-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -5 "${GATE}/err" >&2 || true
  exit 1
fi

# --- pin gate: disabled until stage0.answers carries the captured shas ---
# --enable-deterministic-archives zeroes ar member timestamps/uids so the .a files reproduce.
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
