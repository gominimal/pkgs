#!/bin/sh
# ============================================================================================
# build.sh — B5 (binutils-2.46-glibc) driver.  REVIEW-READY scaffold 2026-07-03.
# ============================================================================================
# A MODERN, GLIBC-LINKED as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip (+ shared libbfd.so),
# built BY R12 gcc-15.2.0 (the musl-linked driver — retargeted onto the from-source glibc-2.42
# sysroot via -B/-L/-isystem), assembled by R10 binutils-2.41 (as/ld on PATH), and LINKED against
# B4's glibc-bedrock-2.42.  The glibc twin of the R10 stage0 assembler:
#   * SR = /usr/lib/glibc-bedrock-2.42 (B4's versioned single-writer sysroot, UAPI co-located).
#   * host wrappers DROP `-static` (glibc is dynamic; produced tools use interp
#     /lib64/ld-linux-x86-64.so.2 and a shared libbfd.so).
#   * PRODUCTION config flags (packages/binutils/build.sh), NOT the stage0 static/minimal set.
#
# ── DELTA vs stage0-binutils-2.41 (R10, musl-static) — see build.ncl banner for the full list ──
#   1. SR musl -> glibc-bedrock-2.42; drop `-static` from the host wrappers + gate.
#   2. HOSTCFLAGS: drop gcc-4.7's `-std=gnu99 -fgnu89-inline` (R12 gcc-15 is modern C); adopt
#      production `-march=x86-64-v3 -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map`.
#   3. config: --enable-ld=default --enable-plugins --enable-shared --enable-new-dtags
#      --enable-default-hash-style=gnu --enable-deterministic-archives --sysconfdir=/etc;
#      make tooldir=/usr; install-strip.  KEEP --disable-gold --disable-gprofng (avoid the C++
#      musl-libstdc++ mixing; default ld = ld.bfd == production's --enable-ld=default choice).
#      OMIT --with-system-zlib (no bedrock zlib yet -> bundled zlib; ABI-inert).
#
# ⚠ INTEGRATION UNVERIFIED (flagged in the readiness note): the produced glibc-dynamic tools + the
#   smoke gate need the glibc loader at build/gate time.  The gate invokes the loader EXPLICITLY
#   ($SR/lib/ld-linux-x86-64.so.2 --library-path ...) so it does NOT depend on a /lib64 symlink; the
#   builder's extract_to_root + /lib64/ld-linux wiring (MEMORY toolchain_extract_to_root_wiring) is
#   what the 368 downstream consumers rely on at B7.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.46.0}"
SRC="binutils-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
T="x86_64-linux-gnu"            # build=host=target; 2020s config.sub canonicalizes natively (no swap)
SR=/usr/lib/glibc-bedrock-2.42  # B4: from-source glibc-2.42 versioned sysroot (libc.so + crt*.o + headers + UAPI)
LOADER="$SR/lib/ld-linux-x86-64.so.2"

command -v gcc >/dev/null 2>&1 || { echo "B5 infra: gcc (R12, gcc-15.2.0) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "B5 infra: as (R10, binutils-2.41) not on PATH — R12's gcc needs it to assemble" >&2; exit 1; }
[ -e "$SR/lib/libc.so" ]   || { echo "B5 infra: B4 glibc sysroot missing at $SR (libc.so)" >&2; exit 1; }
[ -f "$SR/lib/crt1.o" ]    || { echo "B5 infra: B4 glibc startfiles missing at $SR/lib (crt1.o)" >&2; exit 1; }
[ -e "$LOADER" ]           || { echo "B5 infra: B4 glibc dynamic loader missing at $LOADER" >&2; exit 1; }

# ============================================================================================
# libc.so LINKER-SCRIPT FIX — the SEALED B4 artifact's versioned $SR/lib/libc.so baked its
# build-time staging prefix (/build/output/...) into the GROUP() paths (B4 recipe sed bug, fixed
# for future rebuilds) -> dangling in every consumer sandbox -> `ld` can't resolve -lc ->
# "C compiler cannot create executables".  Regenerate a corrected script in a local dir that ld
# searches FIRST; the rewrite is prefix-agnostic (idempotent once B4 is re-attested with the fix).
# ============================================================================================
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B5 infra: libc.so fixup failed" >&2; exit 1; }

# --- unpack (.tar.xz -> needs xz in the closure; --no-same-owner: sandbox userns chown-hostile) ---
tar --no-same-owner -xf "${SRC}.tar.xz"

# ============================================================================================
# CC + CXX WRAPPERS — R12's gcc-cc, retargeted onto the glibc sysroot (DROP -static; glibc dynamic).
# ANTI-POLLUTION: -nostdinc + explicit -isystem the gcc-freestanding include AND the glibc sysroot
# headers (UAPI co-located there), -B/-L the glibc sysroot on link -> every compile+link is
# deterministic and immune to minimal's coin-flip /usr.  See minimal_rootfs_nondeterministic_pollution.
# ============================================================================================
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
# --dynamic-linker: the sandbox has NO /lib64 (gcc's default interp path); the B4 loader is hydrated
# in the versioned sysroot -> bake it so configure's conftest (and every produced bin) can exec in-sandbox.
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -L "${FIXLIB}" -B "\$SR/lib" -L "\$SR/lib" -Wl,--dynamic-linker="\$SR/lib/ld-linux-x86-64.so.2" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# CXX: gold/gprofng (the real C++ subdirs) are DISABLED, so this only ever serves the top-level
# configure's AC_PROG_CXX probe (a headerless `int main(){}`).  -nostdinc is therefore safe here.
GXX_GI="$(g++ -print-file-name=include 2>/dev/null || echo "${GI}")"
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
GI="${GXX_GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/g++ -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/g++ -nostdinc -isystem "\$GI" -isystem "\$SR/include" -L "${FIXLIB}" -B "\$SR/lib" -L "\$SR/lib" -Wl,--dynamic-linker="\$SR/lib/ld-linux-x86-64.so.2" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GXXCC="${BUILDROOT}/gcc-cxx"

cd "${SRC}"

# ============================================================================================
# MODEL-B mtime guard + LOUD regen stubs (ported VERBATIM from R10).  2.46 ships every generated file
# (configure, Makefile.in, the bison/flex parsers, opcodes/i386-tbl.h + i386-init.h, .info + .1 pages).
# Baseline EVERYTHING old, then bump every generated/derived output NEWER so make never invokes an
# absent bison/flex/perl/pod2man; the stubs turn any miss into a NAMED failure.
# ============================================================================================
find . -exec touch -d '2001-01-01 00:00:00' {} +
find . \( -name '*.c' -o -name '*.h' -o -name '*.info' -o -name 'configure' \
          -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
          -o -name 'Makefile.in' -o -name '*.1' -o -name '*.man' -o -name '*.pod' \) \
     -exec touch -d '2020-01-01 00:00:00' {} +
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
# NB flex/lex EXCLUDED (R10 lesson): binutils' AC_PROG_LEX RUNS the lexer + checks its output; a
# fail-loud stub -> "cannot find output from flex; giving up".  With NO flex on PATH autoconf sets
# LEX=: and SKIPS the check (we ship + mtime-guard the generated ldlex.c/deffilep.c).  bison/yacc
# stay: AC_PROG_YACC only sets $YACC, never runs the tool at configure time.
for t in bison yacc m4 gperf perl pod2man help2man texi2pod \
         autoconf autoheader autom4te aclocal automake autoreconf libtoolize makeinfo; do
  printf '#!/bin/sh\necho "B5 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; mtime guard missed it, add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# ============================================================================================
# src_configure — top-level, OUT-OF-TREE.  PRODUCTION packages/binutils/build.sh flags, glibc-linked.
#   --enable-ld=default : ld.bfd (C) is the default `ld` — exactly production's choice.
#   --enable-plugins    : dlopen linker plugins (glibc has real dlopen; the musl-static R10 could not).
#   --enable-shared     : build libbfd.so/libopcodes.so (the shared libs; production ships them).
#   --enable-new-dtags --enable-default-hash-style=gnu --enable-deterministic-archives : prod ABI/determinism.
#   --disable-gold --disable-gprofng : the C++ subdirs -> would drag R12's MUSL libstdc++.a into a glibc
#     link (the mixing hazard).  Default ld is ld.bfd anyway, so the 368 pkgs are unaffected.  (Divergence
#     from production, which builds gold under a glibc host g++; documented in the readiness note.)
#   --with-system-zlib OMITTED : no seed-rooted bedrock zlib -> bundled zlib (ABI-inert).
# Production determinism CFLAGS (byte-parity intent for B6); the wrapper layers -nostdinc/-isystem on top.
# ============================================================================================
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

# ============================================================================================
# src_compile / src_install — production `tooldir=/usr` + `install-strip`.  --prefix stays /usr so
# as/ld bake the CORRECT final prefix; DESTDIR redirects the install into $OUTPUT_DIR.
# ============================================================================================
make -j"$(nproc)" tooldir=/usr MAKEINFO=true
make -j"$(nproc)" tooldir=/usr MAKEINFO=true DESTDIR="${OUTPUT_DIR}" install-strip

# Drop libtool archives (they bake the dead build path in dependency_libs).
rm -f "${OUTPUT_DIR}${LIBDIR}"/*.la 2>/dev/null || true

# ============================================================================================
# triplet symlinks — add RELATIVE x86_64-linux-gnu-<tool> aliases so a target-prefixed lookup also
# resolves.  RELATIVE (not /usr/bin/$f) so the target isn't DANGLING inside $OUTPUT_DIR at stage time.
# ============================================================================================
cd "${OUTPUT_DIR}/usr/bin"
for f in *; do
  case "$f" in x86_64-linux-gnu-*) continue ;; esac
  ln -sf "$f" "x86_64-linux-gnu-$f"
done

# ============================================================================================
# SMOKE GATE — the just-built as+ld must assemble+link a trivial GLIBC-DYNAMIC exe that RUNS (proves
# the whole toolchain end-to-end).  Uses R12's gcc as the driver but forces the freshly-built as/ld
# via -B $OUTPUT_DIR/usr/bin and the glibc sysroot via -B/-L $SR/lib.  The exe is glibc-dynamic, so it
# is run via an EXPLICIT loader invocation (no /lib64 symlink dependency).  FAIL-SHUT.
# ============================================================================================
NAS="${OUTPUT_DIR}/usr/bin"
GATE="${BUILDROOT}/asgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
printf 'int main(void){ return 42; }\n' > "${GATE}/t.c"
set +e
# LD_LIBRARY_PATH: --enable-shared means the fresh as/ld dynamically link libbfd/libopcodes/libsframe,
# staged at $OUTPUT_DIR/usr/lib (their RUNPATH=/usr/lib points at the not-yet-installed location).
# -L $FIXLIB: this direct gcc call bypasses the wrapper, so it needs the corrected libc.so script too.
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
  echo "B5-AS-LD-GATE: PASS (new glibc-linked as+ld assembled+linked a running glibc-dynamic exe; exit=${rrc})" >&2
else
  echo "B5-AS-LD-GATE: FAIL (compile rc=${crc}, run rc=${rrc}, want run=42); tail:" >&2
  tail -8 "${GATE}/err" >&2 || true
  exit 1
fi

# ============================================================================================
# BYTE-IDENTITY: NOT sealed at B5 by design (a different compiler than the prebuilt built it -> different
# bytes; readiness risk #3).  --enable-deterministic-archives + --build-id=none + -ffile-prefix-map keep
# the artifact reproducible for the B6 differential-coreutils proof, but there is no `sha256sum -c` gate
# here.  See stage0.answers.
# ============================================================================================
