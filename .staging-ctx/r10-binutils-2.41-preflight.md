# R10 (stage0-binutils-2.41) — FINAL pre-flight (2026-07-02, R9 = CONFIRMED CC)

Deeper wall-prediction now that R9 (gcc-4.7.4) is a **built + sealed** compiler, not a hypothesis.
Complements `r10-binutils-findings.md` (2026-07-01); this doc records the DELTA + one fix applied.
DRAFT ONLY — not built / not enqueued / not committed.

> **UPDATE 2026-07-03:** SUPERSEDED — historical pre-flight. R10 binutils-2.41 is BUILT + SEALED
> (trust-grade SLSA-L4, attested in Confidential Space); **B3 IS CLOSED** (spine sealed through R11
> gcc-10.4.0). Every predicted wall below (gnu89 C-dialect on libctf/libsframe, Model-B regen,
> tooldir/ldscripts output gap) is RESOLVED HISTORY, not an open risk. Read as a record of the
> reasoning, not as a live enqueue decision. Current frontier: R12 gcc-15.2.0 (built + functional,
> re-sealing now after the content-hash aliasing stopgap; durable fix = issue #14) → B4 = glibc
> (conventional musl→glibc, recipe designed, NOT built). See MEMORY `r5_binutils_progress.md`.

## VERDICT: READY to enqueue (medium confidence). One likely wall pre-cleared in build.sh.
> **UPDATE 2026-07-03:** This verdict fired — R10 was enqueued, built, and SEALED. The walls below are history.
The recipe is structurally sound and is the faithful gcc-built analog of R5 (tcc-built 2.30). The
draft's four load-bearing decisions all check out against R9's proven shape. The single realistic
first-run wall (gcc-4.7 C-dialect on the new libctf/libsframe subdirs) has been mitigated in place.
Remaining risk is Model-B regen naming + output-completeness (both self-revealing / non-fatal).

## Task items 1–4 — verified

1. **gcc-cc wrapper drives R9's gcc-4.7.4, not R6's 4.0.4 — CONFIRMED.** R10's build_deps import
   `stage0-gcc-4.7.4` (R9) and NOT `stage0-gcc-4.0.4` (R6); build_deps are non-transitive in this
   ladder (R9's own CC=R6 is not restaged into R10). So `/usr/bin/gcc` in the R10 sandbox is
   unambiguously gcc-4.7.4. R9 installs plain `gcc`/`g++` (`--program-transform-name=` empty), so the
   wrapper's hardcoded `/usr/bin/gcc` + `/usr/bin/g++` resolve correctly. binutils is C, so the C
   wrapper (compile branch `-nostdinc -isystem $GI -isystem $SR/include`; link branch adds
   `-B/-L $SR/lib -static`) onto musl-bedrock-1.2.5 is the right shape — identical bytes to R9's
   wrapper. NOTE: R9 already PROVED this exact wrapper builds a large host-C codebase (gcc's own
   libiberty/libcpp/gcc host side), so binutils host-C is LOW risk, not first-exercise.

2. **`--prefix=/usr` + `DESTDIR=$OUTPUT_DIR`, NOT the R8 writable-staging-prefix — CONFIRMED correct.**
   Verified R8's idiom (`STAGE=$BUILDROOT/gcc-math` then publish) exists solely because mpc's build-
   time link reads mpfr's INSTALLED `.la` at a logical libdir under a read-only /usr — a library-rung
   phenomenon. binutils has no cross-package installed-`.la` build dep (its libbfd/libopcodes refs are
   relative, in-tree, resolved pre-install), and it installs prefix-BAKING binaries: `ld`/`as` compile
   their libdir/ldscripts search path in, so `--prefix` MUST be the final `/usr`. A `$BUILDROOT/stage`
   prefix would bake a dead build path into `ld`. The draft is right; the forward-map note is wrong for
   this rung (the prior findings doc already flags this — concur, high confidence).

3. **Deps — CONFIRMED complete, incl. the one the task list omits.** build.ncl carries gcc-4.7.4 (CC) +
   **binutils-2.30 (R5, as/ld/ar/ranlib on PATH — R9's gcc shells out to these; gcc bundles neither)**
   + musl-1.2.5 (R7 sysroot) + diffutils + xz + bash/make/sed/grep/coreutils/tar/findutils/gawk. The
   R5 dep is the subtle one and it IS present (+ a `command -v as` fail-loud preflight). No perl dep is
   needed (only man-page regen wants it, which the mtime guard suppresses). No external zlib dep — 2.41
   ships in-tree `zlib/` (assumption; verify the top-level dir listing at pin time; R5 built zlib too).

4. **Top walls — see ranked list below.** config.sub is 2023-06-23 (musl-native) → **no donor swap**,
   and the triple is `x86_64-linux-gnu` (GNU, always known) → doubly no swap. gold/gprofng disabled.

## THE key deepening vs the prior doc: C-dialect wall is MED, not LOW — and I pre-cleared it

The prior doc ranked "gcc-4.7 too old for 2.41 C source" as **[LOW] #4**, reasoning from CORE binutils
(bfd/opcodes/gas/ld), which is genuinely gnu89-clean. That under-weights the **new** subdirs. Concrete
mechanism, now that R9 is the confirmed CC:

- **gcc-4.7 DEFAULTS to `-std=gnu89`.** In gnu89 a C99 *for-loop initial declaration* (`for(int i…)`)
  is a **HARD ERROR**, not a warning — so `--disable-werror` (already passed) does NOT rescue it.
- **libctf (~2019) and libsframe (~2022)** — absent from R5's 2.30, enabled by default in 2.41 — are
  modern C and use exactly those constructs. So the DEFAULT-dialect build is likely to die in libctf/
  libsframe with `'for' loop initial declarations are only allowed in C99 mode`.
- **Why you can't just add `-std=gnu99`:** a bare `inline` means opposite things in gnu89 (emit an
  out-of-line copy) vs c99 (no external symbol). Flipping the whole tree to plain gnu99 risks
  `undefined reference` LINK failures in the OLD bfd/opcodes headers. The safe combo is
  **`-std=gnu99 -fgnu89-inline`** = C99 syntax + gnu89 inline linkage (both flags exist in gcc-4.7).

**FIX APPLIED (build.sh):** set `HOSTCFLAGS="-g -O2 -std=gnu99 -fgnu89-inline"` and pass it as
`CFLAGS="${HOSTCFLAGS}"` on the top-level configure env (propagates to every host subdir via the
tree's HOST_EXPORTS). Preserves binutils' internal default `-g -O2` so only the dialect changes.
Clearly commented + REVERTIBLE (drop CFLAGS to let the cloud name the first offender). Fallback if
libctf still walls on a genuine C11 keyword (`_Alignas`/`_Atomic`, added gcc-4.8/4.9) or a musl-header
gap: `--disable-libctf` (ld/objdump lose CTF display — fine for bedrock); libsframe has no clean
disable but is small + C99-only, so gnu99 carries it. `bash -n` re-passes after the edit.

## Resolved: prior doc's #1 open question — R9's STATIC libstdc++.a

Prior doc asked "does R9 install a static libstdc++.a?" (the top-level `AC_PROG_CXX` probe does a
`-static` link). **RESOLVED: yes, and it's captured.** R9's build.ncl has a dedicated output
`cxx_libs = { glob = "usr/lib/*.a" }` added *specifically* because "WITHOUT these R9's g++ links
nothing … as R11's builder (workflow-caught 2026-07-01)" — i.e. libstdc++.a + libsupc++.a land at
`usr/lib/` and ship in R9's closure. So predicted-wall #3 (CXX probe) is DE-RISKED: the headerless
`int main(){}` probe under the gcc-cxx wrapper (`-static`, `-nostdinc` safe — no headers used) will
find libstdc++.a. gold/gprofng disabled ⇒ even a non-working C++ is non-fatal at top level.

## Predicted walls, re-ranked with R9 confirmed

1. **[MED] gcc-4.7 gnu89-default vs libctf/libsframe C99 for-loop-decls** — *pre-cleared* by the
   CFLAGS fix above. Was the prior doc's under-rated [LOW] #4; the concrete gnu89 mechanism makes it
   the most likely first-run failure. Watch also for `_Alignas`/`_Atomic`/`_Generic` (gcc-4.8/4.9-only)
   in libctf — CFLAGS can't fix those; `--disable-libctf` is the escape.
2. **[MED] Model-B regen trigger** — 2.41 ships bison/flex parsers (ld/ldgram.c, ld/ldlex.c,
   binutils/{arparse,deffilep,mcparse,rcparse,sysinfo}.c, gas/*) + pod2man/texi2pod `.1` man pages.
   The aggressive mtime guard (all→2001, then outputs→2020) plus LOUD stubs handles it and NAMES any
   miss. Man-page chain: `.1`(2020) > `.pod`(2020, equal ⇒ up-to-date) > `.texi`(2001, untouched) ⇒
   no texi2pod/perl. Solid design; iterate if a stub fires.
3. **[MED-LOW] Output completeness — ldscripts + the native tooldir are NOT captured.** A native
   binutils (build=host=target) installs a **tooldir** at `/usr/x86_64-linux-gnu/{bin,lib/ldscripts}`
   (plain as/ld/ar/… copies for a same-triple gcc to find, + the emulation ldscripts). The output
   globs are `usr/bin/*`, `usr/lib/*.a`, `usr/include/**` — these MISS `usr/x86_64-linux-gnu/**` and
   `usr/lib/ldscripts/`. NOT a build failure: `ld` embeds its default emulation scripts (genscripts),
   and R11's gcc finds as/ld on PATH via `/usr/bin`. But if R11 (native x86_64-linux-gnu) probes the
   tooldir first and wants external ldscripts, add an OutputData glob `usr/x86_64-linux-gnu/**` (and/or
   `usr/lib/ldscripts/**`) to build.ncl. Left UNCHANGED (design/staging decision; PATH fallback works)
   — flagged for the operator. Also: `libiberty.a` is NOT installed without `--enable-install-libiberty`
   (the ncl comment lists it as a possible output — it won't appear; harmless, it's build-internal).
4. **[LOW] libctf/libsframe musl-portability** (endian.h/qsort_r) — musl-1.2.5 HAS qsort_r (added
   1.2.3, GNU signature) + endian.h/error.h, so low. Fallback `--disable-libctf` as above.
5. **[LOW] zlib table regen** — bundled zlib ships generated tables; the draft (correctly) omits R5's
   tcc-era `-DDYNAMIC_CRC_TABLE=1 -DBUILDFIXED=1`. If a `make crc32.h`/`makefixed` fires, re-add.
6. **[LOW] `--disable-plugins` vs downstream LTO** — R11 will `--disable-lto` (lto-plugin is a .so,
   won't link static-musl), so ld needs no plugin support here. Revisit only if a later rung wants it.
7. **[LOW→NIL] as/ld/ranlib not on PATH** — the prior doc's [HIGH] #1; already fixed in build.ncl
   (R5 dep present) + fail-loud preflight. Downgraded to non-issue.

## Nits (not fixed — non-blocking)
- `-j1` is conservative; binutils is far lighter than gcc — could raise `-j` if the queue timeout is
  tight, but `-j1` removes the OOM variable for the capture run. Keep for run #1.
- byte-identity: `-g` embeds source paths in debug sections → non-reproducible ACROSS build dirs, but
  fine for record-at-pin-time on a fixed builder path (matches upstream default). `--enable-
  deterministic-archives` zeroes ar member stamps. Confirm as/ld embed no `__DATE__/__TIME__` at pin.

## Fix summary
- **build.sh:** added `HOSTCFLAGS="-g -O2 -std=gnu99 -fgnu89-inline"` → `CFLAGS=` on the configure env
  (mitigates predicted-wall #1; commented + revertible). `bash -n` clean.
- No build.ncl change (deps already complete; the tooldir/ldscripts output gap is flagged, not
  auto-changed — it's a staging design call and PATH fallback works).
