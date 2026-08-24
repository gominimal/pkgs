# B4 glibc-2.42 cold-bootstrap recipe design (workflow wf_14427df6, 2026-07-03)

Confidence: medium

## build.sh skeleton
```sh
#!/bin/sh
# ============================================================================
# B4 = packages/glibc-bedrock-2.42/build.sh  — COLD first-glibc-2.42.
# NOT a patch to production packages/glibc/build.sh (that 38-line file is the
# STEP-5 native-rebuild shape: glibc already in /usr, ./configure && make).
# This is the crosstool-NG/cross-LFS headers-first dance production never needed.
#
# Ingredients (all bedrock, seed-rooted): R12 stage0-gcc-15.2.0 (musl-linked,
# --disable-shared), R10 binutils-2.41 (unprefixed as/ld/ar), stage0-linux-
# headers-6.12.43 (/usr/include/{linux,asm,asm-generic}), R7 musl-1.2.5 at
# /usr/lib/musl-bedrock-1.2.5 (CC's OWN libc, NOT the target), R8 gmp/mpfr/mpc,
# image python3 3.14.5 + make/gawk/sed/grep/bison/m4/tar/xz.
# ============================================================================
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.42}"
GCCVER=15.2.0
BUILDROOT="$(pwd)"
GCC=/usr/bin/gcc; GXX=/usr/bin/g++          # R12 native drivers
SR=/usr/lib/musl-bedrock-1.2.5              # R7 musl = CC's own libc (BUILD_CC only)
GI="$($GCC -print-file-name=include)"       # R12 freestanding hdrs (stddef/stdarg) - libc-agnostic
TGT=x86_64-linux-gnu
GCCLIBDIR=/usr/lib/gcc/$TGT/$GCCVER         # where R12's libgcc.a lives (Pass-2 overwrite target)
SYSROOT="$BUILDROOT/sysroot"                # BUILD-TIME DESTDIR staging tree (NEVER shipped as-is)
PUB_REL=usr/lib/glibc-bedrock-2.42          # single-writer versioned sysroot (the anti-coin-flip output)

# ---- THE CROSS TRIPLE (solves the AC_TRY_RUN wedge) ----
# build_alias != host_alias (same cpu+os, distinct VENDOR) -> autoconf sets
# cross_compiling=yes (configure:1307) -> AC_RUN_IFELSE take cross defaults, no
# target binary executed. Identical cpu(x86_64)+os(linux-gnu)+ABI(-gnu) => sysdeps
# selection is byte-identical to native => still a NATIVE x86_64 glibc.
# HARDCODE both (do NOT use config.guess: nondeterministic + may emit ...-musl here).
BUILD=x86_64-pc-linux-gnu
HOST=x86_64-bedrock-linux-gnu

# ============ infra guards (fail LOUD; all are configure critic_missing progs) ============
for t in gcc as ld ar ranlib bison gawk make sed grep m4 python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "B4 infra: missing $t" >&2; exit 1; }
done
[ -f "$SR/lib/libc.a" ]               || { echo "B4: R7 musl sysroot missing at $SR" >&2; exit 1; }
[ -d /usr/include/linux ] && [ -d /usr/include/asm ] || { echo "B4: linux UAPI missing" >&2; exit 1; }
[ -f /usr/lib/gcc-math/lib/libgmp.a ] || { echo "B4: R8 gmp/mpfr/mpc missing" >&2; exit 1; }
# assert /usr/include is UNPOLLUTED (only kernel UAPI; no foreign libc headers) - see
# minimal_rootfs_nondeterministic_pollution. If a musl/glibc leaf wrote here, --with-headers is poisoned.
[ ! -e /usr/include/stdio.h ] && [ ! -e /usr/include/features.h ] \
  || { echo "B4: /usr/include polluted by a libc leaf (stdio.h/features.h present) - abort" >&2; exit 1; }

# ============ seed kernel UAPI into the staging sysroot (glibc gets it via --with-headers, ============
# ============ NOT via the coin-flip /usr). glibc headers #include <linux/...> so this MUST co-locate. ==
mkdir -p "$SYSROOT/usr/include" "$SYSROOT/usr/lib" "$SYSROOT/usr/include/gnu"
cp -a /usr/include/linux /usr/include/asm /usr/include/asm-generic "$SYSROOT/usr/include/"

# ============ BUILD_CC = R12 musl-static wrapper (verbatim R12 gcc-cc). ==================
# glibc RUNS build-host helper programs during the build; they need a working host libc.
# Static musl is fine (throwaway, emit data). This is the ONLY musl touch-point.
cat > "$BUILDROOT/build-cc" <<WRAP
#!/bin/sh
INC="-isystem $GI -isystem $SR/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $GCC -nostdinc \$INC "\$@";; esac; done
exec $GCC -nostdinc \$INC -B $SR/lib -L $SR/lib -static "\$@"
WRAP
chmod +x "$BUILDROOT/build-cc"; BUILD_CC="$BUILDROOT/build-cc"
# NOTE: CC for glibc itself is BARE $GCC. glibc's own Makeconfig forces -nostdinc and
# builds the include path (-isystem $GI -isystem <--with-headers>), which NEUTRALIZES R12's
# baked --with-native-system-header-dir=$SR/include, so musl can never leak into a libc object.
# Do NOT wrap CC with a hardcoded --sysroot that does not exist at Pass-1/3 time.

# ============ production-parity determinism flags (PRESERVED byte-for-byte; per-pass) ============
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
CF="$MARCH -O2 -pipe -gno-record-gcc-switches"   # -gno-record: stop wrapper/sysroot flags leaking into DW_AT_producer
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
TOOLS="AR=ar RANLIB=ranlib AS=as LD=ld NM=nm OBJCOPY=objcopy OBJDUMP=objdump READELF=readelf STRIP=strip"

tar --no-same-owner -xof "glibc-${VERSION}.tar.xz"
SRC="$BUILDROOT/glibc-${VERSION}"

# common configure (cold deltas vs production: distinct triple, --with-headers, BUILD_CC).
# NB: do NOT add libc_cv_forced_unwind / libc_cv_c_cleanup - VERIFIED ABSENT from glibc-2.42
# configure (0 occurrences); those checks were removed ~2.26/2.35. Adding dead cache vars is noise.
common_configure() {  # runs in $PWD build dir; re-emits -ffile-prefix-map for THIS dir
  echo "rootsbindir=/usr/sbin" > configparms
  env CC="$GCC" CXX="$GXX" BUILD_CC="$BUILD_CC" $TOOLS \
      CFLAGS="$CF -ffile-prefix-map=$(pwd)=/builddir" CXXFLAGS="$CF -ffile-prefix-map=$(pwd)=/builddir" \
      "$SRC/configure" \
        --prefix=/usr --host="$HOST" --build="$BUILD" \
        --with-headers="$SYSROOT/usr/include" \
        --enable-kernel=6.1 --enable-stack-protector=strong \
        --disable-nscd --disable-werror --without-selinux \
        libc_cv_slibdir=/usr/lib
}

# ============ PASS 1 — glibc headers + csu crt + stub libc.so into $SYSROOT ============
# (cross-LFS "install start files"). Feeds the OPTIONAL Pass 2 libgcc rebuild.
mkdir -p "$BUILDROOT/b1"; cd "$BUILDROOT/b1"; common_configure
make install-bootstrap-headers=yes install-headers DESTDIR="$SYSROOT"
make -j"$(nproc)" csu/subdir_lib
install -Dm644 csu/crt1.o csu/crti.o csu/crtn.o -t "$SYSROOT/usr/lib"
$GCC -nostdlib -nostartfiles -shared -x c /dev/null -o "$SYSROOT/usr/lib/libc.so"   # dummy so -lc resolves
[ -f "$SYSROOT/usr/include/gnu/stubs.h" ] || touch "$SYSROOT/usr/include/gnu/stubs.h"

# ============ PASS 2 — OPTIONAL libgcc-vs-glibc rebuild, GATED ON THE COUPLING PROBE ============
# R12 built libgcc.a against MUSL. glibc's Makeconfig links libc.so.6 with STATIC -lgcc (gnulib:=-lgcc);
# the baked libgcc.a code is libc-AGNOSTIC integer/soft-float arithmetic and x86_64 has NATIVE TLS
# (no emutls), so this is *probably* ABI-safe -> DEFAULT = SKIP Pass 2 (see first_probe).
# ---- CRITICAL, load-bearing correction ----
# If the probe FAILS and Pass 2 IS run: -lgcc resolves via `gcc -print-libgcc-file-name` = R12's
# INTERNAL $GCCLIBDIR, which --sysroot / -B $SYSROOT do NOT override. `install-target-libgcc
# DESTDIR=$SYSROOT` therefore changes NOTHING in Pass 3. To actually consume the rebuilt libgcc you
# MUST overwrite R12's on-disk libgcc.a in place (install-target-libgcc DESTDIR=/) OR pass an explicit
# -B $GCCLIBDIR-of-rebuild on the Pass-3 link. Requires gcc-15.2.0 SOURCE as a B4 Source (fresh sandbox
# => R12's build tree does NOT persist; "cd into R12 build" is impossible).
if [ "${B4_REBUILD_LIBGCC:-0}" = 1 ]; then
  tar --no-same-owner -xof "gcc-${GCCVER}.tar.xz"; mkdir -p "$BUILDROOT/b2"; cd "$BUILDROOT/b2"
  # host compile of xgcc/cc1 uses R12's musl gcc-cc/gcc-cxx wrappers (reproduce from stage0-gcc-15.2.0).
  env CC="$BUILDROOT/build-cc" CXX="$BUILDROOT/gcc-cxx" AR=ar RANLIB=ranlib \
    "$BUILDROOT/gcc-${GCCVER}/configure" --prefix=/usr --build="$TGT" --host="$TGT" --target="$TGT" \
      --enable-languages=c --disable-shared --disable-bootstrap --disable-multilib --disable-nls \
      --disable-lto --disable-libsanitizer --disable-libssp --disable-libgomp --disable-libquadmath \
      --disable-libitm --disable-libatomic --without-isl \
      --with-gmp=/usr/lib/gcc-math --with-mpfr=/usr/lib/gcc-math --with-mpc=/usr/lib/gcc-math \
      --with-build-sysroot="$SYSROOT" --with-native-system-header-dir=/usr/include --program-transform-name=
  make -j"$(nproc)" all-target-libgcc CFLAGS_FOR_TARGET="-g -O2 -B $SYSROOT/usr/lib -L $SYSROOT/usr/lib"
  make install-target-libgcc DESTDIR=/    # overwrite R12's $GCCLIBDIR/libgcc.a with the glibc-coupled build
fi

# ============ PASS 3 — glibc FINAL (production step-5 shape; ABI flags verbatim) ============
mkdir -p "$BUILDROOT/b3"; cd "$BUILDROOT/b3"; common_configure
make -j"$(nproc)" MAKEINFO=:              # ':' matches glibc's `ifneq ($(strip $(MAKEINFO)),:)` guard; NOT 'true'
make install DESTDIR="$OUTPUT_DIR"        # SEALED artifact -> $OUTPUT_DIR/usr (prefix=/usr, ABI/interp correct)
make install DESTDIR="$SYSROOT"           # refresh staging tree for in-sandbox localedef + later rungs
sed '/RTLDLIST=/s@/usr@@g' -i "$OUTPUT_DIR/usr/bin/ldd"   # production line, PRESERVED

# ============ SINGLE-WRITER SYSROOT PUBLISH (mirrors R7 musl) - anti /usr coin-flip ============
# The SEALED artifact ALREADY ships to $OUTPUT_DIR/usr (that is what production/interp needs). The
# versioned tree is an ADDITIONAL clean copy so B5 can build -nostdinc against a tree that no other
# producer writes. Kernel UAPI copied IN so glibc headers' <linux/...> includes resolve standalone.
PUB="$OUTPUT_DIR/$PUB_REL"
mkdir -p "$PUB/include" "$PUB/lib"
cp -a "$OUTPUT_DIR/usr/include/." "$PUB/include/"
cp -a /usr/include/linux /usr/include/asm /usr/include/asm-generic "$PUB/include/"   # co-locate UAPI
cp -a "$OUTPUT_DIR"/usr/lib/*.a "$OUTPUT_DIR"/usr/lib/*.so* "$OUTPUT_DIR"/usr/lib/*.o "$PUB/lib/" 2>/dev/null || true
cp -a "$OUTPUT_DIR/usr/lib/gconv" "$PUB/lib/gconv" 2>/dev/null || true
# libc.so is a linker SCRIPT with absolute GROUP(/usr/lib/...) paths -> repoint into the versioned tree
# so B5 (-L $PUB/lib) resolves within the clean sysroot, not the musl-polluted /usr:
sed -i "s@/usr/lib/@$PUB/lib/@g" "$PUB/lib/libc.so" 2>/dev/null || true

# ============ locale generation (production commands). Runs the JUST-BUILT localedef => needs AVX2 ============
# (compiled -march=x86-64-v3, executed on the builder). Non-fatal for the cold hop: the 368 pkgs need
# build-TIME links, not locales; defer to B5 if it fails cold.
mkdir -vp "$OUTPUT_DIR/usr/lib/locale"
LD_SO="$OUTPUT_DIR/usr/lib/ld-linux-x86-64.so.2"; [ -x "$LD_SO" ] || LD_SO="$OUTPUT_DIR/lib64/ld-linux-x86-64.so.2"
( localedef --prefix="$OUTPUT_DIR" -i en_US -f ISO-8859-1 en_US \
  && localedef --prefix="$OUTPUT_DIR" -i en_US -f UTF-8 en_US.UTF-8 ) \
  || echo "WARN: cold locale gen failed; defer en_US to B5 (non-blocking)" >&2

# ============ FAIL-SHUT CORRECTNESS GATE (the R4-class silent-corruption tripwire) ============
# B4-RUNNABLE surfaces ONLY (R12 is --disable-shared: NO libgcc_s.so.1 exists anywhere yet, so
# cross-DSO C++ EH and backtrace(3) CANNOT run here - DEFER those to B5 acceptance, the first rung
# that emits libgcc_s.so.1). Here exercise, STATIC-linked against the FRESH glibc:
#   (a) float/printf: printf("%.17g|%.1Lf", 1.5+2.25, 1.5L) == expected  <- R4 fmt_fp long-double class
#   (b) __thread TLS read/write across two TUs                            <- the coupling path that matters
#   (c) setjmp/longjmp round-trip
#   (d) STATIC C++ throw/catch in ONE binary: $GXX -static -static-libgcc -static-libstdc++
#       (uses libgcc_eh.a, which R12 --disable-shared DID build) -> validates static EH tables
# Compile with: $GCC/$GXX -static -isystem $OUTPUT_DIR/$PUB_REL/include -B/-L $OUTPUT_DIR/$PUB_REL/lib
# glibc 2.34+ merged libpthread into libc => no -lpthread needed. FAIL on any mismatch => exit 1 (no seal).

```

## build.ncl deps
- build.sh (Local)
- glibc-2.42.tar.xz (Source, extract=false, sha256=d1775e32e4628e64ef930f435b67bb63af7599acb6be2b335b9f19f16509f17f — carry verbatim from production glibc/build.ncl; already mirrored)
- gcc-15.2.0.tar.xz (Source, extract=false — REQUIRED for the OPTIONAL Pass-2 libgcc rebuild; same sha as R12's source; trips stage_internal_deps_gap since it is a SECOND Source so wire the input by hand or rely on builder graph-hydration. OMIT only if you commit to the probe-proven skip)
- stage0-gcc-15.2.0 (R12 — CC/CXX, musl-linked, --disable-shared)
- stage0-binutils-2.41 (R10 — as/ld/ar/ranlib)
- stage0-linux-headers-6.12.43 (kernel UAPI at /usr/include/{linux,asm,asm-generic})
- stage0-musl-1.2.5 (R7 — CC's OWN libc at /usr/lib/musl-bedrock-1.2.5; BUILD_CC only)
- gmp/mpfr/mpc (R8 — at /usr/lib/gcc-math; only consumed if Pass 2 runs)
- python (image 3.14.5 — configure critic_missing hard-abort; runs gen-as-const.py, constants CC-derived)
- bison 3.8.2 (configure critic_missing; UNCONDITIONALLY load-bearing — intl/plural.c is NOT shipped in the 2.42 tarball, so bison always regenerates it; mtime reasoning is moot)
- m4 1.4.21 (bison runtime dep)
- gawk 5.x (configure critic_missing; gen-tunables.awk/gen-sorted.awk/errlist.awk)
- make 4.4.1 (configure critic_missing; == INSTALL newest-verified)
- sed 4.9
- grep 3.12
- tar
- xz 5.8.3
- gzip
- coreutils
- diffutils
- findutils
- bash
- perl 5.42.0 (tests/mtrace only — parity, low-risk; NOT build-required)

## outputs
Model on production glibc/build.ncl all_outputs (the ~12 globs: bins/sbins/etc/libs/crts/lib_audit/lib_locale/lib_gconv/libexec_getconf/i18n/locales/includes under usr/) so the SEALED artifact at $OUTPUT_DIR/usr can byte-match the prebuilt glibc leaf at B7 — the artifact ships to plain /usr with --prefix=/usr, libc_cv_slibdir=/usr/lib (do NOT ship under the versioned subdir; interp /lib64/ld-linux-x86-64.so.2 and slibdir must stay canonical). PLUS the ADDITIONAL single-writer versioned sysroot for B5 consumption: sysroot_lib = { glob = "usr/lib/glibc-bedrock-2.42/lib/**", allow_data = true } | OutputLib (libc.so is a linker script -> allow_data); sysroot_include = { glob = "usr/lib/glibc-bedrock-2.42/include/**" } | OutputData. NO glibc self-import and NO replace_on_cycle — cold from-source is the entire point of B4.

## risk register
- [high] libgcc coupling silently mis-resolved: even if Pass 2 rebuilds libgcc against glibc-stage1, glibc's static -lgcc resolves via `gcc -print-libgcc-file-name` = R12's INTERNAL $GCCLIBDIR, which --sysroot/-B $SYSROOT do NOT override. `install-target-libgcc DESTDIR=$SYSROOT` is a no-op and Pass 3 silently links R12's MUSL libgcc.a anyway. This is the exact 'compiles != correct' / R4-silent-corruption class the repo has shipped twice. -> Two valid postures, pick ONE explicitly: (A) DEFAULT SKIP Pass 2 — but only after the first_probe proves musl-libgcc.a is ABI-safe on x86_64 (libc-agnostic arithmetic + native TLS; no cross-DSO EH baked into libc.so.6). (B) If probe fails, Pass 2 MUST overwrite R12's on-disk libgcc.a in place (install-target-libgcc DESTDIR=/) OR pass explicit -B <rebuild-libgcc-dir> on Pass 3's link. Never rely on DESTDIR=$SYSROOT + --sysroot to redirect -lgcc.
- [high] Kernel-header co-location broken in the versioned sysroot: glibc headers #include <linux/errno.h>, <asm/*> etc.; a $PUB/include holding ONLY glibc headers makes every B5 consumer (and the B4 gate) fail 'linux/errno.h: No such file'. LFS avoids this only because glibc+kernel headers co-habit one /usr/include. -> cp -a /usr/include/{linux,asm,asm-generic} into $PUB/include at publish (done in skeleton). Alternatively consumers add -isystem /usr/include alongside -isystem $PUB/include. Verify a hello.c that #includes <stdio.h> compiles against $PUB alone before sealing.
- [medium] /usr coin-flip pollution: musl (/usr/lib/musl-bedrock-1.2.5) + a fresh glibc both touching /usr is the ~50/50 first-writer race; if the SEALED artifact also drops bare /usr/include+/usr/lib libc files, a downstream sandbox merge is nondeterministic. -> The sealed /usr artifact is correct/required (interp+slibdir parity) and musl lives under a VERSIONED subdir so paths do not collide (glibc writes /usr/include/stdio.h, musl writes /usr/lib/musl-bedrock-1.2.5/... — disjoint). Additionally publish the clean versioned /usr/lib/glibc-bedrock-2.42 tree; B5 builds -nostdinc against THAT, never the merged /usr. Assert /usr/include unpolluted before Pass 1 (skeleton guard).
- [low] AC_TRY_RUN wedge / misdetection: native (build==host) configure runs target test programs that cannot execute with no target glibc -> wedge or wrong libc_cv_* defaults. -> VERIFIED-solid: --build=x86_64-pc-linux-gnu != --host=x86_64-bedrock-linux-gnu forces cross_compiling=yes (configure:1307). Same cpu+os+ABI keeps sysdeps native. HARDCODE both triples (no config.guess — nondeterministic + may report -musl). Do NOT add libc_cv_forced_unwind/libc_cv_c_cleanup (VERIFIED absent from 2.42 configure).
- [medium] Correctness gate under-tests and a wrong-but-quiet libc ships (the R4 fmt_fp / tcc-mes lesson). The originally-designed gate (cross-DSO C++ EH + backtrace) is IMPOSSIBLE in B4: R12 is --disable-shared so NO libgcc_s.so.1 exists — those checks fail for lack of the shared unwinder, not for coupling. -> Gate only B4-runnable surfaces STATIC-linked vs the fresh glibc: float/long-double printf (R4 class), __thread TLS across TUs, setjmp round-trip, STATIC C++ throw/catch (-static-libgcc -static-libstdc++, uses libgcc_eh.a which R12 DID build). Explicitly DEFER cross-DSO EH + backtrace(3) to B5 acceptance (first rung emitting libgcc_s.so.1). Fail-shut.
- [medium] Missing build-tool wedge: bison (intl/plural.c NOT shipped -> always regenerated), gawk, make, sed, m4, python all hard-abort configure via critic_missing; a stale/absent one wedges at configure. -> All guarded fail-loud in skeleton; declared in build_deps at exact production versions (make 4.4.1, bison 3.8.2 == INSTALL newest-verified). Use MAKEINFO=: (colon) not 'true' to satisfy glibc's `ifneq ($(strip $(MAKEINFO)),:)` guard (VERIFIED manual/Makefile:32).
- [medium] localedef self-hosting fails cold: runs the just-built localedef (compiled -march=x86-64-v3 -> needs AVX2 on the builder CPU) against a loader the cold sandbox has no /lib64/ld-... for; and locale-archive byte-order is a known glibc non-determinism surface for the B6 a/b gate. -> Wrap locale gen non-fatal (368 pkgs need build-time links not locales; defer to B5). For B6, pin to individual --no-archive locale files or a post-sort; CS builder CPU is AVX2-capable (production floor) so SIGILL risk is low but real.
- [low] Python/data-transform trust surface baked into libc bytes. Reduced from prior scoping: gen-translit.py is ABSENT from 2.42 scripts/ (only gen-as-const.py present), and gen-as-const constants are CC-derived ($(CC) -DGEN_AS_CONST_HEADERS), so python is orchestration-only there. python 3.14.5 is one minor above INSTALL newest-verified (3.13.5). -> Wire glibc's built-in test-as-const cross-check (Makerules re-derives each value via a 2nd CC compile) into the gate. Pin the exact python minor; byte-check any generated-into-libc headers against the prebuilt leaf at B6. No bespoke stage0-python (heavy, glibc-circular closure for zero lineage gain).
- [low] Determinism drift for the B6 DDC a/b gate: sysroot-wrapper -isystem paths can embed in .debug_line file tables; PIE default of R12 vs the production prebuilt gcc unknown; -ffile-prefix-map must map EACH pass's own build dir. -> -gno-record-gcc-switches (covers DW_AT_producer), --build-id=none, ARFLAGS=Drc, -march pinned; re-emit -ffile-prefix-map=$(pwd)=/builddir per pass (skeleton does). Confirm R12's default -fPIE/-no-pie matches the prebuilt before the DDC step. Byte-identity is a B6 goal, not a B4 gate.

## first probe
Cheapest de-risk BEFORE any cloud build — a local R12-style configure+coupling probe in an amd64 debian container (mirror the stage0-gcc-15.2.0 configure-probe pattern), two parts:\n\nPART A (configure/triple sanity, minutes): extract the ALREADY-EXTRACTED glibc-2.42 tree (scratchpad/glibc/glibc-2.42), run `configure --prefix=/usr --host=x86_64-bedrock-linux-gnu --build=x86_64-pc-linux-gnu --with-headers=<kernel-uapi> --enable-kernel=6.1 --disable-nscd --disable-werror libc_cv_slibdir=/usr/lib CC='gcc -nostdinc' BUILD_CC=gcc` and CONFIRM the log says 'checking whether we are cross compiling... yes' and reaches the end without an AC_TRY_RUN wedge. Grep the generated config.status/config.make to confirm it selected sysdeps/x86_64 (native) and did NOT try libc_cv_forced_unwind (VERIFIED absent). This validates the entire cross-triple mechanism for the price of a configure run.\n\nPART B (the libgcc-coupling decision — determines whether Pass 2 exists at all): build a MINIMAL glibc-stage1 (install-headers + csu crt, ~1 subdir) OR just link against a stock debian glibc, then compile a tiny probe with R12's MUSL-built libgcc.a explicitly on the link line: a program exercising (1) __thread TLS, (2) long-double printf %.1Lf (R4 class), (3) STATIC C++ throw/catch (-static-libgcc -static-libstdc++). If all three PASS with musl libgcc.a linked into glibc-linked output => Pass 2 is UNNECESSARY and B4 collapses to cross-triple + headers-first + production one-shot (the cheapest shape). If any FAIL => commit to Pass 2 with the explicit -B / DESTDIR=/ overwrite wiring (NOT the DESTDIR=$SYSROOT no-op). This single probe decides the whole recipe shape before spending a multi-hour cloud glibc build.

## must confirm against real tree
- CONFIRMED against real 2.42 tree: libc_cv_forced_unwind + libc_cv_c_cleanup are ABSENT (0 occurrences) — do NOT add them. critic_missing hard-aborts on GNU ld/make/gawk/bison/compiler/python. intl/plural.c is NOT shipped -> bison unconditionally runs. gen-translit.py is ABSENT (only gen-as-const.py) -> smaller python trust surface. MAKEINFO guard is `ifneq ($(strip $(MAKEINFO)),:)` -> use MAKEINFO=: not true. cross_compiling=yes path exists at configure:1307.
- STILL TO CONFIRM: exact install-bootstrap-headers target name/behavior in 2.42 Makerules (LFS uses `make install-bootstrap-headers=yes install-headers`); verify csu/subdir_lib produces crt1.o/crti.o/crtn.o/Scrt1.o/gcrt1.o at the expected paths.
- STILL TO CONFIRM: R12 stage0-gcc-15.2.0 default PIE posture (-fPIE/-no-pie) and whether its installed libgcc lives exactly at /usr/lib/gcc/x86_64-linux-gnu/15.2.0 (grep the sealed R12 artifact) — the Pass-2 overwrite target and B6 determinism both depend on it.
- STILL TO CONFIRM: that /usr/include in the B4 sandbox contains ONLY stage0-linux-headers UAPI and no foreign libc headers (musl publishes under /usr/lib/musl-bedrock-1.2.5 so it should be clean, but assert it — minimal_rootfs_nondeterministic_pollution).
- STILL TO CONFIRM: whether the SEALED /usr glibc artifact and the versioned /usr/lib/glibc-bedrock-2.42 tree can coexist in a downstream merged /usr without path collision against musl-bedrock (they are disjoint by construction, but run one `minimal run dogfood`-style merge to prove no coin-flip).
- STILL TO CONFIRM: reproduce R12's gcc-cxx musl-static C++ host wrapper verbatim (stage0-gcc-15.2.0/build.sh lines 86-93) for the OPTIONAL Pass-2 host compile of xgcc/cc1.
- BUILDER-SIDE (out of build.sh scope): CAVEAT A breaker_hydrate twinning + CAVEAT B spec_hash cascade on any replace_on_cycle edits — run DUMP_CLOSURE_HASHES before the B7 production flip.
