#!/bin/sh
# ============================================================================================
# build.sh — B6 (coreutils-bedrock-diff) driver.  Scaffolded 2026-07-04.
# ============================================================================================
# The differential twin of production packages/coreutils/build.sh: SAME source, SAME configure
# flags, SAME determinism knobs (-march=x86-64-v3 -O3 -pipe -gno-record-gcc-switches
# -Wl,--build-id=none -ffile-prefix-map, install-strip) — but compiled/assembled/linked by the
# B5 from-source toolchain (gcc-15.2.0-glibc + binutils-2.46-glibc + glibc-bedrock-2.42).
# Output feeds .staging-ctx/b6-compare.sh (Gate-0 + normalized byte compare vs production).
#
# ── The wall classes this recipe defends against (B5 climb, 2026-07-03/04) ──────────────────
#   1. NO /lib64 in the sandbox: FINAL binaries must still carry the PRODUCTION interp
#      (/lib64/ld-linux-x86-64.so.2) or the byte compare is dead on arrival (a longer .interp
#      string shifts every section offset).  Resolution: TWO wrapper link modes —
#        mode "run"  : bake -Wl,--dynamic-linker=$SR/... (for things that must EXEC in-sandbox:
#                      configure conftests, the make-prime-list build-time generator, hello gate)
#        mode "prod" : NO interp override (production-identical link line) for `make all`.
#      Compile flags are IDENTICAL in both modes, so .o files are mode-agnostic.
#      Anything prod-linked that must run is exec'd via the EXPLICIT loader invocation.
#   2. B4's poisoned libc.so linker script: FIXLIB regen, -L$FIXLIB ahead of -B$SR/lib on EVERY
#      link (wrapper AND the direct gcc calls in gates).
#   3. Staged shared libs (B5 binutils' libbfd RUNPATH=/usr/lib): the B5 binutils artifact is a
#      DEP here (hydrated at /usr/lib), so its as/ld/readelf resolve; LD_LIBRARY_PATH pins the
#      B4 sysroot libs first for everything we exec.
#   5. No new output globs that a disabled component would leave empty (breadcrumb glob is
#      always written by this script, unconditionally).
# ============================================================================================
set -ex
VERSION="${MINIMAL_ARG_VERSION:-9.10}"
SRC="coreutils-${VERSION}"
BUILDROOT="$(pwd)"
SR=/usr/lib/glibc-bedrock-2.42            # B4: from-source glibc versioned sysroot (headers+crt+libs+UAPI)
LOADER="$SR/lib/ld-linux-x86-64.so.2"
PROD_INTERP="/lib64/ld-linux-x86-64.so.2" # what production binaries carry; final links must too

[ "$(uname -m)" = "x86_64" ] || { echo "B6 infra: amd64-only (B5 toolchain is amd64)" >&2; exit 1; }

GCCBIN="$(command -v gcc || true)"
[ -n "${GCCBIN}" ]           || { echo "B6 infra: gcc (gcc-15.2.0-glibc) not on PATH" >&2; exit 1; }
command -v as >/dev/null     || { echo "B6 infra: as (binutils-2.46-glibc) not on PATH" >&2; exit 1; }
command -v strip >/dev/null  || { echo "B6 infra: strip (binutils-2.46-glibc) not on PATH — install-strip needs it" >&2; exit 1; }
[ -e "$SR/lib/libc.so" ]     || { echo "B6 infra: B4 glibc sysroot missing at $SR (libc.so)" >&2; exit 1; }
[ -f "$SR/lib/crt1.o" ]      || { echo "B6 infra: B4 glibc startfiles missing at $SR/lib (crt1.o)" >&2; exit 1; }
[ -f "$SR/lib/Scrt1.o" ]     || { echo "B6 infra: B4 glibc PIE startfiles missing (Scrt1.o; gcc is default-pie)" >&2; exit 1; }
[ -e "$LOADER" ]             || { echo "B6 infra: B4 glibc dynamic loader missing at $LOADER" >&2; exit 1; }

# ============================================================================================
# B6-TWIN-GATE (in-recipe half of Gate-0; defeats CAVEAT A at the earliest possible moment).
# The B5 gcc/as host binaries were linked with -Wl,--dynamic-linker=$SR/lib/ld-linux... baked in
# (that is HOW they exec in a /lib64-less sandbox), so the literal string "glibc-bedrock-2.42"
# appears in their bytes.  The production gcc/binutils binaries carry /lib64/... and do NOT
# contain that string.  If the string is absent, the production (or twinned-prebuilt) toolchain
# silently filled the slot -> the differential would be a no-op -> FAIL SHUT.
# ============================================================================================
grep -aq "glibc-bedrock-2.42" "${GCCBIN}" \
  || { echo "B6-TWIN-GATE: FAIL — gcc on PATH (${GCCBIN}) is NOT the B5 gcc-15.2.0-glibc (no $SR interp marker). Twinning substituted the production/prebuilt toolchain; the differential is void." >&2; exit 1; }
grep -aq "glibc-bedrock-2.42" "$(command -v as)" \
  || { echo "B6-TWIN-GATE: FAIL — as on PATH is NOT the B5 binutils-2.46-glibc (no $SR interp marker)." >&2; exit 1; }
echo "B6-TWIN-GATE: PASS (gcc + as carry the $SR interp marker — B5 from-source toolchain confirmed)" >&2

# libc.so LINKER-SCRIPT FIX (wall class 2, same treatment as binutils-2.46-glibc/build.sh): the
# sealed B4 versioned $SR/lib/libc.so baked /build/output/... staging paths into its GROUP()
# entries -> regenerate a corrected, prefix-agnostic script in a dir ld searches FIRST.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B6 infra: libc.so fixup failed" >&2; exit 1; }

# LD_LIBRARY_PATH: everything we exec (conftests + make-prime-list carry the $SR-baked interp;
# the B5 binutils tools need their own staged-at-/usr/lib libbfd) resolves B4 libs FIRST,
# deterministically — immune to the /usr coin-flip (both hydrated glibcs are 2.42, but the twin
# must load the B4 bytes).  Env only: does not touch emitted bytes.
export LD_LIBRARY_PATH="${SR}/lib:/usr/lib"

# ============================================================================================
# CC WRAPPER — the B5 gcc pinned to the B4 sysroot, with a PHASE-SWITCHED link mode.
# ANTI-POLLUTION (wall class 2 + minimal_rootfs_nondeterministic_pollution): -nostdinc, then
# explicitly: B5-gcc freestanding headers -> $SR/include (glibc + UAPI, single-writer) ->
# /usr/include LAST (attr/acl/libcap/gmp headers — the production feature-detection surface;
# any coin-flip glibc headers there are shadowed by $SR).  Link: -L$FIXLIB first (corrected
# libc.so script), -B/-L $SR/lib (B4 crt1/crti/Scrt1 + libs), default dirs then serve
# -lacl/-lattr/-lcap/-lgmp from /usr/lib exactly as production.
# The CC *string* is constant across configure and make (single wrapper path) so config.status
# never sees a flag flip; only the mode file changes.
# ============================================================================================
GI="$("${GCCBIN}" -print-file-name=include)"
[ -d "${GI}" ] || { echo "B6 infra: B5-gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }
echo run > "${BUILDROOT}/.wrap-mode"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
INC="-isystem ${GI} -isystem ${SR}/include -isystem /usr/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${GCCBIN}" -nostdinc \$INC "\$@" ;; esac; done
MODE="\$(cat "${BUILDROOT}/.wrap-mode" 2>/dev/null || echo run)"
if [ "\$MODE" = "run" ]; then
  # in-sandbox-runnable link: bake the B4 loader (no /lib64 in the sandbox — wall class 1)
  exec "${GCCBIN}" -nostdinc \$INC -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" -Wl,--dynamic-linker="${LOADER}" "\$@"
fi
# production-identical link: default interp ${PROD_INTERP} — REQUIRED for the byte compare
exec "${GCCBIN}" -nostdinc \$INC -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# ============================================================================================
# B6-HELLO-GATE — the plan's §7.2 hello smoke pilot, folded in as a fail-shut preflight.
#  (a) mode=run link RUNS DIRECTLY (proves configure conftests will execute), exit 42;
#  (b) mode=prod link carries the PRODUCTION interp, contains NO $SR path leak, and RUNS via
#      the EXPLICIT loader invocation (proves the final-binary link mode end-to-end).
# ============================================================================================
GATE="${BUILDROOT}/b6gate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
printf 'int main(void){ return 42; }\n' > "${GATE}/hello.c"
# (a) run-mode
echo run > "${BUILDROOT}/.wrap-mode"
"${GCCCC}" "${GATE}/hello.c" -o "${GATE}/hello-run"
set +e; "${GATE}/hello-run"; rc_run=$?; set -e
# (b) prod-mode
echo prod > "${BUILDROOT}/.wrap-mode"
"${GCCCC}" "${GATE}/hello.c" -o "${GATE}/hello-prod"
if grep -aq "glibc-bedrock-2.42" "${GATE}/hello-prod"; then
  echo "B6-HELLO-GATE: FAIL — prod-mode binary leaks the $SR path (interp/rpath contamination); bytes would never match production" >&2; exit 1
fi
grep -aq "${PROD_INTERP}" "${GATE}/hello-prod" \
  || { echo "B6-HELLO-GATE: FAIL — prod-mode binary does not carry the production interp ${PROD_INTERP}" >&2; exit 1; }
set +e; "${LOADER}" --library-path "${SR}/lib" "${GATE}/hello-prod"; rc_prod=$?; set -e
if [ "${rc_run}" -eq 42 ] && [ "${rc_prod}" -eq 42 ]; then
  echo "B6-HELLO-GATE: PASS (run-mode direct exec=42; prod-mode interp=${PROD_INTERP}, explicit-loader exec=42)" >&2
else
  echo "B6-HELLO-GATE: FAIL (run-mode rc=${rc_run}, prod-mode rc=${rc_prod}, want 42/42)" >&2; exit 1
fi

# ============================================================================================
# src_unpack + src_configure — PRODUCTION SHAPE, verbatim knobs.
# CFLAGS string is byte-identical to packages/coreutils/build.sh:12 ($(pwd) is the SAME
# in-source dir in both builds and -ffile-prefix-map maps it to /builddir anyway).
# configure runs in mode=run so its AC_RUN_IFELSE conftests can exec (wall class 1); the
# interp flag is link-only and cannot change a feature-detection verdict.
# ============================================================================================
tar --no-same-owner -xof "${SRC}.tar.xz"
cd "${SRC}"

MARCH="-march=x86-64-v3"
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -Wl,--build-id=none -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export ARFLAGS=Drc          # deterministic archives (coreutils ships no .a; belt-and-suspenders)
export LC_ALL=C             # plan §4: pin any in-build sort ordering

echo run > "${BUILDROOT}/.wrap-mode"
FORCE_UNSAFE_CONFIGURE=1 ./configure \
    --prefix=/usr \
    --enable-no-install-program=kill,uptime \
    CC="${GCCCC}"

# Build-time generator(s) that make RUNS during `make all` get linked in mode=run first
# (make-prime-list emits src/primes.h for factor).  `|| true`: if the dist tarball ships
# primes.h fresh enough, the target may be absent/up-to-date — and if some OTHER generator
# needs exec, the prod-mode `make all` below fails LOUDLY on it (fail-shut, add it here).
make -j"$(nproc)" src/make-prime-list || true

# ============================================================================================
# src_compile / src_install — mode=prod: every remaining link is PRODUCTION-IDENTICAL
# (default interp /lib64/..., no rpath, build-id=none).  install-strip runs the B5 strip.
# ============================================================================================
echo prod > "${BUILDROOT}/.wrap-mode"
make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install-strip

# ============================================================================================
# POST-INSTALL DETERMINISM GATES (plan §4 residuals — verify, fail-shut):
#   * interp parity : every installed ELF must carry ${PROD_INTERP}, never the $SR loader;
#   * no build-id   : -Wl,--build-id=none must have held;
#   * no path leak  : neither the build dir nor the $SR prefix may appear in the bytes.
# readelf is the B5 binutils one ($SR-interp-baked, execs in-sandbox; libbfd via LD_LIBRARY_PATH).
# ============================================================================================
for b in "$OUTPUT_DIR/usr/bin/ls" "$OUTPUT_DIR/usr/bin/cat" "$OUTPUT_DIR/usr/bin/sort"; do
  [ -f "$b" ] || { echo "B6-DETGATE: FAIL — expected binary missing: $b" >&2; exit 1; }
  readelf -l "$b" | grep -q "interpreter: ${PROD_INTERP}" \
    || { echo "B6-DETGATE: FAIL — $b does not carry the production interp ${PROD_INTERP}" >&2; exit 1; }
  if readelf -n "$b" | grep -qi 'build.id'; then
    echo "B6-DETGATE: FAIL — $b carries a build-id (knob regression: --build-id=none did not hold)" >&2; exit 1
  fi
  # NB trailing slash: the -ffile-prefix-map TARGET "/builddir" is a LEGITIMATE baked string
  # (production has it too); "${BUILDROOT}/" (e.g. "/build/") must never appear un-mapped.
  if grep -aq "glibc-bedrock-2.42" "$b" || grep -aq "${BUILDROOT}/" "$b"; then
    echo "B6-DETGATE: FAIL — $b leaks a build/sysroot path (nondeterminism the compare would flag)" >&2; exit 1
  fi
done
echo "B6-DETGATE: PASS (prod interp + no build-id + no path leak on ls/cat/sort)" >&2

# ============================================================================================
# B6 GATE-0 BREADCRUMB — machine-readable toolchain identity, consumed by b6-compare.sh as the
# provenance fallback when in-toto resolvedDependencies is empty (queue-mode default; see
# feedback_verify_deps_permissive_with_empty_resolved).  EXCLUDED from the byte compare by path.
# Written unconditionally (wall class 5: the glob must never be empty).
# ============================================================================================
BC="$OUTPUT_DIR/usr/share/coreutils-bedrock-diff"; mkdir -p "$BC"
{
  echo "toolchain=B5-from-source"
  echo "package=coreutils-bedrock-diff-${VERSION}"
  echo "gcc_path=${GCCBIN}"
  echo "gcc_version=$("${GCCBIN}" -dumpfullversion)"
  echo "gcc_sha256=$(sha256sum "${GCCBIN}" | cut -d' ' -f1)"
  echo "as_sha256=$(sha256sum "$(command -v as)" | cut -d' ' -f1)"
  echo "strip_sha256=$(sha256sum "$(command -v strip)" | cut -d' ' -f1)"
  echo "sysroot=${SR}"
  echo "libc_so6_sha256=$(sha256sum "${SR}/lib/libc.so.6" | cut -d' ' -f1)"
  echo "crt1_sha256=$(sha256sum "${SR}/lib/crt1.o" | cut -d' ' -f1)"
  echo "final_link_interp=${PROD_INTERP}"
} > "$BC/B6-TOOLCHAIN.txt"
cat "$BC/B6-TOOLCHAIN.txt" >&2

echo "B6: coreutils-bedrock-diff build complete — compare with .staging-ctx/b6-compare.sh" >&2
