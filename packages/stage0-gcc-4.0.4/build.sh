#!/usr/bin/env bash
# ============================================================================================
# build.sh — R6 (stage0-gcc-4.0.4 core, pass1) driver. DRAFT 2026-06-30. GATED ON R5 (binutils).
# ============================================================================================
# Model-B adaptation of live-bootstrap steps/gcc-4.0.4/pass1.sh: ship ALL generated files, SKIP the
# autoconf/aclocal/autoheader/libtoolize/bison/flex/perl regen (none exist in the bedrock env), and
# pin generated-file mtimes newest so make never re-triggers an absent tool. Only the 3 load-bearing
# SOURCE seds are hand-ported. The C-only keystone (U1) — first from-source gcc, amd64-direct.
#
# ## THE CC BRIDGE (the fix vs the prior raw-`CC=tcc` draft) ##################################
# CC = the musl-cc WRAPPER over the SEALED tcc-musl2 (R4a/s4), NOT raw tcc and NOT R3's mes-prefixed
# tcc. tcc's libtcc1 references `abort` in libc; a single `-lc` leaves the libtcc1<->libc cycle
# unresolved on a static link. The wrapper (ported verbatim from R5 binutils build.sh:36-43) puts the
# crt explicitly and libc TWICE around libtcc1 on LINK, and passes -c/-S/-E straight through on COMPILE.
# So per-file gcc compiles are plain tcc-musl2; only the executable links (cc1, xgcc, cpp, the gen*
# tools, collect2) take the crt+libc-twice path. AR="tcc-musl2 -ar" (per the R5 precedent / ladder-prep
# §iv.B). See build.ncl header + .staging-ctx/bedrock-ladder-prep-2026-06-29.md.
#
# ## WHY R5 MUST BE GREEN FIRST ###############################################################
# Once xgcc (the gcc we are building) exists, the build compiles libgcc2.c with xgcc, which emits .s and
# calls `as`; it indexes archives with `ranlib`. Those are R5 binutils-2.30 on PATH (/usr/bin). The env
# sets no system AR/RANLIB, so R5 MUST seal before this rung. (CC for building gcc *itself* is tcc-musl2,
# which assembles internally — `as` is only consumed by the freshly-built xgcc for libgcc.)
#
# ## OOM / TIMEOUT (gcc-4.0.4 is an OOM pole — operator preflight) ############################
#   - Keep -j1 EVERYWHERE (set below). The cc1 link under tcc-musl2 is the peak-RAM moment.
#   - Before pushing R6: `container builder start --cpus 6 --memory 16G` (MEMORY tooling_container_builder_resources).
#   - Raise the queue task timeout for this rung; warm RemoteCache so the closure (s4 + R4 musl + R5
#     binutils + the shell tools) is all HIT and not rebuilt in-task.
#   - Queue R6 LAST / serially (claim order is filename-lexicographic; a wedge eats an overnight).
# ============================================================================================
set -ex
VERSION="${MINIMAL_ARG_VERSION:-4.0.4}"
TARBALL="gcc-core-${VERSION}.tar.bz2"
SRC="gcc-${VERSION}"               # NB: tarball is gcc-core-*, extracted dir is gcc-* (verified)
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"          # build=host=target; shipped 2005 config.sub canonicalizes this — NO donor swap
TCC=/usr/bin/tcc-musl2             # the SEALED, s4-gate-passed musl-linked tcc (CC backend + AR)

# --- unpack (.tar.bz2 -> needs bzip2 in the closure) ---
# --no-same-owner: sandbox userns; tar's chown-to-archived-uid fails "Cannot change ownership" (as R4b/R5).
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# ============================================================================================
# CC WRAPPER (musl-cc) — ported VERBATIM from R5 stage0-binutils-2.30/build.sh:36-43.
#   LINK  (no -c/-S/-E): explicit crt1+crti, then args, then libc.a libtcc1.a libc.a crtn (libc TWICE,
#                        after libtcc1 — breaks the abort/libtcc1<->libc static cycle). musl crt prefix
#                        is /usr/lib (NOT /usr/lib/mes).
#   COMPILE (-c/-S/-E):  pass through to tcc-musl2 unchanged (per-file gcc compiles are unaffected).
# ============================================================================================
cat > "${BUILDROOT}/musl-cc" <<'WRAP'
#!/bin/sh
# ANTI-POLLUTION (same fix as R5 binutils): compile/link against R4b's CLEAN single-writer musl sysroot
# at /usr/lib/musl-bedrock, NOT the coin-flip /usr — the glibc-linked shell tools carry a glibc whose
# usr/include + usr/lib/libc.a collide with musl in minimal's unordered first-writer-wins rootfs. -nostdinc
# + explicit crt/libc from $MB make every gcc compile+link deterministic. (libtcc1.a: s3 sole writer, safe.)
MB=/usr/lib/musl-bedrock
for a in "$@"; do case "$a" in -c|-S|-E) exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" "$@" ;; esac; done
# -L "$MB/lib": gcc links -lm/-lc/-lpthread; in musl those are EMPTY stubs (math etc. live in libc.a).
# Without this, tcc's default lib path finds GLIBC's /usr/lib/libm.so (the coin-flip /usr) and drags in
# glibc _dl_x86_cpu_features/errno. Pointing -L at the sysroot resolves -lm to musl's empty $MB/lib/libm.a.
exec /usr/bin/tcc-musl2 -nostdinc -I "$MB/include" -nostdlib -static -L "$MB/lib" \
  "$MB/lib/crt1.o" "$MB/lib/crti.o" "$@" \
  "$MB/lib/libc.a" /usr/lib/tcc/libtcc1.a "$MB/lib/libc.a" "$MB/lib/crtn.o"
WRAP
chmod +x "${BUILDROOT}/musl-cc"
MUSLCC="${BUILDROOT}/musl-cc"

# ============================================================================================
# Model-B src_prepare: ONLY the 3 load-bearing SOURCE seds from pass1.sh (the inverted R3 trap —
# there are no .patch files, the fixes hide as inline seds). Record as TIER-3-equivalent in
# docs/bedrock-patch-provenance.md. We do NOT do any of pass1.sh's autotools/bison/flex/perl regen.
# ============================================================================================
# (1) tcc: tcc-0.9.27 chokes on the flexible/zero-length array `ix86_attribute_table[]`. gcc/config/i386
#     is the SHARED x86 backend, compiled for x86_64-linux-gnu too -> this APPLIES to amd64.
sed -i 's/ix86_attribute_table\[\]/ix86_attribute_table\[10\]/' gcc/config/i386/i386.c
# (2) musl: `struct siginfo` -> `siginfo_t` in the unwinder. The __x86_64__ path uses the same lines.
sed -i 's/struct siginfo/siginfo_t/' gcc/config/i386/linux-unwind.h
# (3) the C_alloca -> alloca pair is applied POST-configure (pass1.sh ordering), below.

# ============================================================================================
# MTIME GUARD (Model-B regen avoidance) — the central trap. The tarball ships BOTH the generated
# outputs AND their .y/.l/.in/.ac/.tab/.pl sources; if any source is newer than its generated output
# after extraction, make invokes the (absent) bison/flex/perl/autoconf and the build dies. Cure:
#   (a) baseline EVERY file OLD, then (b) bump EVERY generated/derived output to a single newest mtime
#   so make sees the whole generated chain up-to-date and never runs a regen recipe.
# Belt-and-suspenders: regen-tool stubs on PATH (below) turn any MISSED file into a LOUD, named failure
# (a missing tool would otherwise silently clobber a shipped file via `$(TOOL) ... > $@`).
# ============================================================================================
find . -exec touch -d '2001-01-01 00:00:00' {} +
# single touch call => identical mtime for every generated file (no intra-list ordering inversion):
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' \
                  -o -name 'aclocal.m4' -o -name 'Makefile.in' \
                  -o -name '*.info' -o -name '*.gmo' \) -print) \
      gcc/c-parse.y gcc/c-parse.c gcc/c-parse.h \
      gcc/gengtype-yacc.c gcc/gengtype-yacc.h gcc/gengtype-lex.c \
      intl/plural.c libcpp/ucnid.h fixincludes/fixincl.x

# Regen-tool guard: if the mtime guard missed a file, FAIL LOUDLY naming the tool instead of silently
# corrupting a shipped generated file. (None of these exist in the bedrock env; the build legitimately
# needs none of them under Model-B.) makeinfo/msgfmt are handled cleanly via MAKEINFO=true + --disable-nls.
STUBS="${BUILDROOT}/regen-stubs"
mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl \
         autoconf autoheader autom4te aclocal automake autoreconf libtoolize \
         autoconf-2.61 autoheader-2.61 autom4te-2.61 aclocal-1.9 aclocal-1.10 automake-1.10 autoreconf-2.61; do
  cat > "${STUBS}/${t}" <<STUB
#!/bin/sh
echo "R6 MODEL-B GUARD: '${t}' was invoked (\$*) -> a generated file is being regenerated. The mtime" >&2
echo "guard missed it; add it to the touch list in build.sh. Model-B must NOT regen (no autotools/" >&2
echo "bison/flex/perl in bedrock). Failing loudly rather than silently clobbering a shipped file." >&2
exit 1
STUB
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# ============================================================================================
# src_configure — out-of-tree, per subdir, in dependency order: libiberty -> libcpp -> gcc.
#   CC  = musl-cc wrapper (the fix). AR = tcc-musl2 -ar; RANLIB=true (tcc -ar self-indexes — matches
#         R4 musl + R5 binutils). CFLAGS=-D HAVE_ALLOCA_H (musl ships alloca.h).
#   --disable-nls: SAFE Model-B simplification (deviates from lb, matches R5 binutils) — removes the
#     intl/gettext/msgfmt + intl/plural.c(bison) regen surface entirely; functionally identical compiler.
#   --disable-shared / --program-transform-name= : as live-bootstrap pass1.
#   --disable-multilib: NET-NEW vs lb (lb builds i386, never hits this). gcc-4.0.4 on x86_64-linux
#     DEFAULTS to multilib -> it would try to build a 32-bit (m32) libgcc, needing a 32-bit musl crt +
#     an i386 assembler target the amd64-only spine deliberately does NOT have. Force 64-bit-only.
#   config.sub: NOT swapped (shipped 2005 config.sub knows x86_64-linux-gnu). No --with-sysroot needed.
# Each conftest link goes through the wrapper (crt+libc-twice) -> running musl binaries (proven on R5).
# ============================================================================================
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

# (3) POST-configure source seds (pass1.sh applies these after the configure loop):
sed -i 's/C_alloca/alloca/g' libiberty/alloca.c
sed -i 's/C_alloca/alloca/g' include/libiberty.h

# ============================================================================================
# src_compile — Model-B: NO explicit `make gengtype-yacc.c` prestep (it's shipped + mtime-guarded).
#   LIBGCC2_INCLUDES=-I/usr/include : libgcc2.c finds musl headers.
#   STMP_FIXINC=  : disable the fixincludes stamp (musl headers are clean; no fixinc).
#   MAKEINFO=true : skip texinfo (shipped .info kept; rule won't run under the mtime guard anyway).
#   -j1 throughout (OOM pole). CC/AR/RANLIB were baked into each Makefile by configure (not re-passed,
#     matching R5 binutils + lb).
# ============================================================================================
ln -s . "build/build-${TARGET}"
mkdir -p build/gcc/include
ln -s ../../../gcc/gsyslimits.h build/gcc/include/syslimits.h
# libgcc's build demands stmp-fixinc -> fixincludes/fixinc.sh, but we never configure the fixincludes dir
# (fixincludes exists only to PATCH broken glibc headers; musl's are clean).  Drop a no-op fixinc.sh so
# stmp-fixinc is satisfied and gcc's include-fixed stays empty — libgcc then resolves headers from musl
# via CPATH.  Path build/build-<tgt>/fixincludes resolves through the `ln -s .` symlink to build/fixincludes.
mkdir -p build/fixincludes
printf '#!/bin/sh\nexit 0\n' > build/fixincludes/fixinc.sh
chmod +x build/fixincludes/fixinc.sh
# The freshly-built xgcc compiles crtbegin/crtend/libgcc with its OWN baked include+lib path
# (/usr/include, /usr/lib = the coin-flip /usr), NOT the musl-cc wrapper — so pollution reaches it
# (glibc's /usr/include/bits/errno.h -> absent linux/errno.h).  CPATH/LIBRARY_PATH prepend R4b's clean
# musl sysroot to xgcc's search so crtstuff/libgcc resolve musl's errno.h + musl crt/libc, not glibc's.
export CPATH="/usr/lib/musl-bedrock/include"
export LIBRARY_PATH="/usr/lib/musl-bedrock/lib"
for dir in libiberty libcpp gcc; do
  make -j1 -C "build/${dir}" \
    LIBGCC2_INCLUDES="-I/usr/lib/musl-bedrock/include" \
    STMP_FIXINC= MAKEINFO=true
done

# ============================================================================================
# src_install — DESTDIR=$OUTPUT_DIR redirects all writes off the read-only /usr into /build/output.
# ============================================================================================
mkdir -p "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/install-tools/include"
make -j1 -C build/gcc install STMP_FIXINC= MAKEINFO=true DESTDIR="${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/include"
rm -f "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/include/syslimits.h"
cp gcc/gsyslimits.h "${OUTPUT_DIR}${LIBDIR}/gcc/${TARGET}/${VERSION}/include/syslimits.h"

# ============================================================================================
# BYTE-IDENTITY GATE — record-at-pin-time (no upstream amd64 gcc-4.0.4 fixed point). Disabled for the
# capture run; pin cc1/xgcc/cpp/libgcc.a shas into stage0.answers, then re-enable.
# ============================================================================================
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"

# ============================================================================================
# OPERATOR NOTES — DRAFT open items (resolve before/at first green build):
#   * AR="tcc-musl2 -ar" follows the task spec + R5 precedent. R5 used tcc -ar because no `ar` existed
#     yet; here R5 binutils `ar`/`ranlib` ARE on PATH and produce deterministic, indexed archives.
#     If libgcc.a/libiberty.a archiving misbehaves under tcc -ar, the lower-risk fallback is
#     `AR=ar RANLIB=ranlib` (both on PATH) — tcc-musl2's linker reads standard binutils archives.
#   * PRE-COMPILE GO/NO-GO (do this LOCALLY before any cloud build — readiness §6 checklist ②):
#     run the sealed amd64 tcc-musl2 STANDALONE over the mega-blobs that stress its codegen hardest —
#       gcc/c-parse.c (222KB bison output: huge switch/jump tables, big static state arrays),
#       gcc/gengtype-lex.c (129KB flex output: dense computed-goto/table dispatch),
#       gcc/gengtype-yacc.c (49KB) — plus libiberty's _doprnt.c / floatformat.c (FP codegen).
#     A clean `-c` of these = cheap keystone go/no-go. This is the analogue of the s2a..s2i diaggot
#     bisection that caught fixes A/B/C — see "tcc-musl2 codegen stressors" in the StructuredOutput.
#   * varargs + >=4-arg-call smoke test against the sealed tcc-musl2 (the real out-of-catalog gate;
#     MEMORY tcc_mes_miscompiles_ge4arg_calls + tcc_mes_varargs_valist_fix). gcc's calls are deep.
