#!/usr/bin/env bash
# ============================================================================================
# build.sh — R10 (stage0-binutils-2.41) driver.  DRAFT 2026-07-01.
# ============================================================================================
# A MODERN as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip, built BY the from-source gcc-4.7.4
# (R9), linked STATIC against musl-1.2.5 (R7).  This is the gcc-built analog of R5
# (stage0-binutils-2.30, which tcc built) — so every tcc-ism from R5 is GONE:
#   * CC/CXX = the gcc-cc / gcc-cxx WRAPPERS over R9's gcc-4.7.4 (copied from R9), NOT a
#     musl-relinked tcc; no libtcc1<->libc "libc twice" link dance.
#   * AR=ar RANLIB=ranlib are REAL binutils (R5, on PATH), NOT `tcc -ar`.
#   * no @PLT symbol strip, no asm-file rm, no per-subdir configure hand-loop — 2.41 has a proper
#     top-level configure and gcc handles the amd64 opcodes/i386-tbl.h path fine.
#
# ⚠ THE DEP THE TASK LIST OMITTED: R9's gcc SHELLS OUT to `as`/`ld` (and `ranlib` for archives) to
#   turn its .s output into .o / link.  gcc bundles NEITHER.  So R5 binutils-2.30 MUST be on PATH
#   (it is, via build.ncl build_deps).  Without it the very first compile dies "as: not found".
#
# ⚠ UNCERTAIN — iterate against the cloud (see .staging-ctx/r10-binutils-findings.md):
#   (a) Model-B regen: 2.41 ships gas/ld/binutils bison+flex parsers (ldgram.c, ldlex.c, deffilep.c,
#       arparse.c, …) + pod2man man pages; the mtime guard + LOUD stubs below name any that regen.
#   (b) top-level configure runs AC_PROG_CXX; the gcc-cxx wrapper is PROBE-ONLY (int main(){}) —
#       gold/gprofng (the real C++ consumers) are disabled, so no <vector>/-nostdinc header wall.
#   (c) config.sub is 2023 (musl-native) → NO donor swap expected.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.41}"
SRC="binutils-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
T="x86_64-linux-gnu"            # build=host=target; 2023 config.sub canonicalizes this natively (no swap)
SR=/usr/lib/musl-bedrock-1.2.5  # R7: clean single-writer musl sysroot (libc.a + crt*.o + headers)

command -v gcc >/dev/null 2>&1 || { echo "R10 infra: gcc (R9, gcc-4.7.4) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "R10 infra: as (R5, binutils-2.30) not on PATH — R9's gcc needs it to assemble" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "R10 infra: R7 musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }

# --- unpack (.tar.xz -> needs xz in the closure) ---
# --no-same-owner: sandbox userns; tar's default chown-to-archived-uid fails "Cannot change
# ownership … Invalid argument" (the R8 wall #1; every upper rung's untar needs it).
tar --no-same-owner -xf "${SRC}.tar.xz"

# ============================================================================================
# CC + CXX WRAPPERS — gcc-cc libc-using variant, copied VERBATIM from R9 (only the backend gcc
# changed: it is now R9's gcc-4.7.4 at /usr/bin/gcc).  ANTI-POLLUTION: -nostdinc + explicit
# -isystem the gcc-freestanding include AND the musl sysroot headers, -B/-L the sysroot -static on
# link — so every compile+link is deterministic and immune to minimal's coin-flip /usr (the
# glibc-linked shell tools' usr/include + usr/lib/libc.a collide with musl in the unordered,
# first-writer-wins rootfs overlay).  See MEMORY minimal_rootfs_nondeterministic_pollution.
# ============================================================================================
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# CXX: gold/gprofng (the real C++ subdirs) are DISABLED, so this only ever serves the top-level
# configure's AC_PROG_CXX probe (a headerless `int main(){}`).  -nostdinc is therefore safe here;
# if any enabled subdir ever compiles real C++ this wrapper must gain the libstdc++ include dirs
# (drop -nostdinc for CXX, or add -isystem <g++ c++ header dir>) — see findings (b).
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

# ============================================================================================
# MODEL-B mtime guard + LOUD regen stubs.  2.41 ships every generated file (configure, Makefile.in,
# the bison/flex parsers, opcodes/i386-tbl.h + i386-init.h, the .info + .1 man pages).  If tar leaves
# any .y/.l/.in/.pod newer than its shipped output, make invokes the (absent) bison/flex/perl/pod2man
# and either dies or silently clobbers a good generated file.  Cure: baseline EVERYTHING old, then
# bump every generated/derived output NEWER; the stubs turn any miss into a NAMED failure.
# (bedrock has no autoreconf/bison/flex/perl — Model-B must never regen.)
# ============================================================================================
find . -exec touch -d '2001-01-01 00:00:00' {} +
# broad, deliberately over-inclusive: every .c/.h is a generated-or-hand-written OUTPUT and must be
# >= any .y/.l/.pod source; touching them all to one newer mtime prevents ALL regen (equal-or-newer
# ⇒ make sees "up to date").  .o still compiles (no .o exists yet).
find . \( -name '*.c' -o -name '*.h' -o -name '*.info' -o -name 'configure' \
          -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
          -o -name 'Makefile.in' -o -name '*.1' -o -name '*.man' -o -name '*.pod' \) \
     -exec touch -d '2020-01-01 00:00:00' {} +
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
# NB flex/lex EXCLUDED: binutils-2.41's AC_PROG_LEX actually RUNS the lexer + checks its output, so a
# fail-loud stub -> "cannot find output from flex; giving up". With NO flex/lex on PATH, autoconf sets LEX=:
# and SKIPS the check (we ship + mtime-guard the generated ldlex.c/deffilep.c, so flex is never really needed).
# bison/yacc stay: AC_PROG_YACC only sets $YACC, it never runs the tool at configure time.
for t in bison yacc m4 gperf perl pod2man help2man texi2pod \
         autoconf autoheader autom4te aclocal automake autoreconf libtoolize makeinfo; do
  printf '#!/bin/sh\necho "R10 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; mtime guard missed it, add it to the touch list (or Model-A regen is required)." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# ============================================================================================
# src_configure — top-level, OUT-OF-TREE.  gmp/mpfr/mpc are NOT referenced (binutils has no bignum
# middle-end).  --disable-gold/gprofng: the C++ / bison-heavy components we neither need nor want to
# fight on static-musl.  --disable-plugins: bedrock needs no dlopen linker plugins (and static musl's
# dlopen is a stub) — drop the libdl surface.  --enable-install-libbfd: guarantee libbfd.a/libopcodes.a
# + bfd.h land in /usr (so the OutputLib/headers globs are non-empty).  --with-sysroot= : empty, so ld
# bakes no sysroot prefix (it finds libs via the -L the consumer passes).  MAKEINFO=true: skip texinfo.
# ============================================================================================
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
# PREDICTED-WALL-#1 mitigation (gcc-4.7 C-dialect vs binutils' NEW subdirs) — pre-cleared here.
# gcc-4.7 DEFAULTS to -std=gnu89, in which a C99 "for-loop initial declaration" (for(int i=...)) is a
# HARD ERROR, not a warning — so --disable-werror does NOT save it. The OLD subdirs (bfd/opcodes/gas/
# ld/binutils/libiberty) are gnu89-clean, but the NEW ones (libctf ~2019, libsframe ~2022 — absent in
# R5's 2.30) are modern C and use exactly those constructs. Force -std=gnu99 so they compile.
# -fgnu89-inline is REQUIRED alongside it: a bare `inline` has GNU89 semantics (emit an out-of-line
# copy) vs C99 semantics (no external symbol) — flipping the whole tree to plain gnu99 would risk
# "undefined reference" LINK errors in the old bfd/opcodes headers. The combo = C99 syntax + gnu89
# inline linkage, the known-safe way to build 2020s C on a 2012 gcc. Both flags exist in gcc-4.7.
# Setting CFLAGS at top-level configure propagates to every host subdir via the tree's HOST_EXPORTS.
# FALLBACK if libctf still walls (genuine C11 keyword like _Alignas/_Atomic, or a musl-header gap):
# add --disable-libctf (ld/objdump lose CTF display — acceptable for bedrock). libsframe has no clean
# disable but is small + C99-only, so gnu99 should carry it. REVERTIBLE: drop CFLAGS to fall back to
# binutils' internal default (-g -O2) and let the cloud name the first offending file.
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

# ============================================================================================
# src_compile / src_install — -j1 (conservative; binutils is far lighter than gcc but the sandbox
# is memory-constrained).  MAKEINFO=true again on both.  DESTDIR redirects install off the read-only
# /usr into $OUTPUT_DIR; --prefix stays /usr so as/ld bake the CORRECT final prefix (this is why R10
# does NOT use R8's writable-staging-prefix idiom — binaries bake their prefix; see findings).
# ============================================================================================
make -j1 MAKEINFO=true
make -j1 MAKEINFO=true DESTDIR="${OUTPUT_DIR}" install

# Drop libtool archives: they bake the dead build path in dependency_libs; downstream rungs link the
# static .a directly (same rm as R8's gmp/mpfr/mpc).  With --disable-shared these are static-only .la.
rm -f "${OUTPUT_DIR}${LIBDIR}"/*.la

# ============================================================================================
# triplet symlinks — a native binutils installs the plain names (as, ld, ar, …); add RELATIVE
# x86_64-linux-gnu-<tool> aliases so a target-prefixed lookup (R9/R11 gcc's cross-style probe) also
# resolves.  RELATIVE (not /usr/bin/$f) so the target isn't DANGLING inside $OUTPUT_DIR at stage time
# (the R5 lesson); -f for idempotence; skip already-prefixed names so the glob can't self-nest.
# ============================================================================================
cd "${OUTPUT_DIR}/usr/bin"
for f in *; do
  case "$f" in x86_64-linux-gnu-*) continue ;; esac
  ln -sf "$f" "x86_64-linux-gnu-$f"
done

# ============================================================================================
# SMOKE GATE — the just-built as+ld must assemble+link a trivial static-musl exe that RUNS (proves
# the whole toolchain end-to-end, not just "it compiled").  Uses R9's gcc as the driver but forces
# the freshly-built as/ld via -B $OUTPUT_DIR/usr/bin.  FAIL-SHUT.
# ============================================================================================
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
  echo "R10-AS-LD-GATE: PASS (new as+ld assembled+linked a running static-musl exe; exit=${rrc})" >&2
else
  echo "R10-AS-LD-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -5 "${GATE}/err" >&2 || true
  exit 1
fi

# ============================================================================================
# BYTE-IDENTITY GATE — record-at-pin-time (no upstream amd64 binutils-2.41 fixed point; the ladder is
# amd64-direct).  --enable-deterministic-archives zeroes ar member timestamps/uids so libbfd.a etc.
# are reproducible.  DISABLED for the capture run; pin the tool + lib shas into stage0.answers, then
# re-enable this line.
# ============================================================================================
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
