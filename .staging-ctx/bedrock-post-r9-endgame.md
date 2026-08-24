# Bedrock post-R9 endgame — R10 / R11 / glibc-2.42 consolidated (2026-07-02)

> **UPDATE 2026-07-03 (ground-truth pointer):** everything below the R9 seal has SHIPPED. **B3 IS
> CLOSED** — R10 (binutils-2.41), R11 (gcc-10.4.0 pivot), and the whole R5→R11 spine are FULLY SEALED,
> trust-grade SLSA-L4, attested in CS. The section-3 "which modern gcc" question RESOLVED to **R12 =
> gcc-15.2.0 direct** (the 5-major 10.4→15.2 jump PASSED; gcc-12.4.0 fallback not needed). R12 is BUILT
> + FUNCTIONAL but **not yet sealed**: its seal hit a content-hash ALIASING bug (production
> linux_headers ≡ stage0-linux-headers share artifact-sha 083cdb → one poisoned `.intoto` mirror slot).
> UNBLOCKED 2026-07-03 via a trust-neutral STOPGAP (copy the clean dual-signed production envelope over
> the shared slot); durable spec-qualified-mirror fix = issue #14 (review+rebuild-gated). R12 seals when
> its from-scratch rebuild finishes (~1-3h). **B4 = glibc** is DESIGNED (recipe below is superseded in
> the specifics — see per-section notes), NOT built. Target DECIDED = **glibc** (conventional
> musl→glibc, 368 pkg recipes change ZERO lines); Python posture SETTLED (image python 3.14.5,
> orchestration-only). Read the per-section UPDATE notes before acting on any recommendation here.

Ties together the three deep-prep passes done after R9 (gcc-4.7.4) sealed:
- R11 = **gcc-10.4.0** (THE PIVOT) — build strategy + walls → `r11-gcc-10.4-buildplan.md`
- R10 = **binutils-2.41** — readiness + predicted walls → `r10-binutils-2.41-preflight.md`
- B4  = **glibc-2.42** hop — rung order + biggest risk + first move → `b4-glibc-2.42-scoping.md`

The through-line the three passes surface together: **the pivot (gcc-10.4.0) is bounded on BOTH sides.**
R9's C++98-only g++ caps it at ≤10.4 from below (build-capability); glibc-2.42's GCC≥12.1 floor rejects
it from above (consumer). A modern-gcc rung between the pivot and glibc was therefore structurally
inevitable — it is not a version-choice regret, it is geometry.

---

## 1. R11 = gcc-10.4.0 (the pivot) — build strategy

> **UPDATE 2026-07-03:** SHIPPED + SEALED. The pivot survived — wall #1 (R9-g++ C++11 capability) did
> NOT bite; the R9.5=gcc-4.8.5 contingency was not needed. "Not committed/enqueued" below is stale.


**build-with-cxx VERDICT: build WITH C++ — do NOT `--disable-build-with-cxx`.** gcc-4.8+ deleted the
C-only host path; gcc-10's host source is `.cc`. A real C++ host now exists (R9's g++), so
`CC=gcc-cc` (R9's gcc) + `CXX=gcc-cxx` (R9's g++). R9's static libstdc++ availability is CONFIRMED
(R9 build.ncl captures `cxx_libs=usr/lib/*.a` + `cxx_includes=usr/include/c++/**` → land at
`/usr/lib/libstdc++.a` + `/usr/include/c++/4.7.4/`; build.sh fail-loud-checks both).

**R9 fixes that TRANSFER (load-bearing):**
- (b) gcc-cc wrapper onto R7 musl sysroot (`-nostdinc -isystem …/musl-bedrock-1.2.5`, `-B/-L $SR/lib -static`).
- (c) `CFLAGS_FOR_TARGET/CXXFLAGS_FOR_TARGET="-B -L $SR/lib -static"` — else libstdc++ configure's link
  test trips `GCC_NO_EXECUTABLES` ("Link tests are not allowed").
- (d) `sed os/gnu-linux → os/generic` — on a **-gnu triplet over musl**, libstdc++'s `configure.host`
  picks `os/gnu-linux`, whose `ctype_base.h` uses glibc `_ISupper/_ISalpha` that musl lacks. gcc-10's
  musl awareness keys on a `*-linux-MUSL` triplet, which we deliberately don't use → it does NOT rescue
  us. **Alpine builds libstdc++ "unpatched" only because it uses the -musl triplet that auto-selects
  os/generic; our inherited -gnu-on-musl posture does not get that for free.**

**R9 fixes that DROP / are NEW:**
- DROP: `--disable-build-with-cxx` (obsolete gcc-4.8+), `--disable-libmudflap` (removed gcc-4.9).
- NEW: `--disable-libitm` (still present, musl-risky), `--disable-libstdcxx-pch` (OOM-pole reducer).
- KEEP: `--without-isl` (no ISL rung, ever), `--disable-lto` (lto-plugin is a `.so`), fixincludes no-op
  stub, C++14 fail-shut smoke gate.

**gcc-cxx wrapper hardened (findings wall #5 SOLVED, not "watched"):** `-nostdinc -nostdinc++` then
re-add explicitly **C++ std hdrs → gcc freestanding → musl C hdrs**, else `-isystem` sorts musl BEFORE
the C++ dirs and `<cstdlib>`'s `#include_next <stdlib.h>` steps over musl. Wrapper discovers
`CXX_BASE_DIR`/`CXX_TGT_DIR` from a `c++config.h` probe (no hard-coded builder version).

**CAUTION (recorded):** the as-delivered draft build.sh had DROPPED both load-bearing fixes (c) and (d)
and its smoke gate used R9's `$GI` instead of the new g++'s own include dir. All three RESTORED in the
corrected build.sh. This would have failed the first cloud build for two avoidable plumbing reasons,
masking the true pivot verdict (wall #1) — a "compiles ≠ correct / verify load-bearing claims" repeat.

**Top walls (ranked):**
1. 🔴 **C++11-capability gap in R9's g++.** `--disable-bootstrap` means R9's 4.7.4 g++ compiles every
   gcc-10 `.cc` directly; 4.7.4's *partial* C++11 could bite a TU if gcc-10 opportunistically enables
   `-std=gnu++11`. **No build.sh tuning fixes this** — the first cloud build is the only arbiter.
   Contingency: R9.5 = gcc-4.8.5 intermediate (build.ncl CC import is the 1-line swap-point).
2. 🟠 **libstdc++ target link → `GCC_NO_EXECUTABLES`** — guarded by restored fix (c); if it still trips,
   check `libstdc++-v3/config.log` for a missing crt path under `$SR/lib`.
3. 🟡 **libstdc++ ctype on musl** — guarded by restored os/generic sed (d); escalation = honest
   `x86_64-linux-musl` triplet (bigger change, ripples into multiarch dir names — last resort).
- Lower: CXX-wrapper include order (cloud-arbitrated), Model-B regen on the larger generated set,
  R10-not-yet-sealed sequencing (build.ncl uses R5 binutils-2.30 stand-in), OOM/wall-time.

**Deliverables:** `packages/stage0-gcc-10.4.0/build.sh` (rewritten) + `r11-gcc-10.4-buildplan.md`. Not
committed/enqueued. Pre-flight: swap build.ncl CC import to `../stage0-binutils-2.41` once R10 seals;
mirror `gcc-10.4.0.tar.xz` + re-verify sha `c9297d5bcd7c…`; `container builder start --cpus 6 --memory 16G`.

---

## 2. R10 = binutils-2.41 — readiness + predicted walls

> **UPDATE 2026-07-03:** SHIPPED + SEALED. "READY to enqueue" is now history — R10 built and sealed as
> the R11 assembler. The gnu89 C-dialect wall (gnu99+fgnu89-inline fix) held.

**READY to enqueue (medium confidence).** The recipe is the faithful gcc-4.7.4-built analog of R5
(tcc-built 2.30); all 4 task items verify:
- gcc-cc wrapper drives **R9's** gcc-4.7.4 (R6 not in closure; build_deps non-transitive). R9 already
  PROVED this exact wrapper builds a large host-C codebase → binutils host-C is LOW risk.
- `--prefix=/usr` + `DESTDIR=$OUTPUT_DIR` is correct (ld BAKES its libdir/ldscripts search path → an
  R8-style writable-staging prefix would poison it with a dead build path).
- Deps complete incl. the easy-to-miss **R5 binutils-2.30** (R9's gcc shells out to as/ld/ar/ranlib;
  gcc bundles none) + a `command -v as` fail-loud preflight. config.sub is 2023 musl-native → no swap.

**Top wall (the key deepening — prior doc under-rated it LOW):** gcc-4.7 DEFAULTS to `-std=gnu89`,
where C99 for-loop-decls are a **HARD ERROR** (`--disable-werror` does not help). The NEW subdirs
**libctf (~2019) / libsframe (~2022)** — absent from R5's 2.30 — use exactly those constructs → likely
first-run death in libctf/libsframe.
**FIX APPLIED (build.sh):** `HOSTCFLAGS="-g -O2 -std=gnu99 -fgnu89-inline"` → `CFLAGS=` on the top-level
configure (propagates via HOST_EXPORTS). `-fgnu89-inline` is REQUIRED so flipping to gnu99 doesn't
cause "undefined reference" from the old bfd/opcodes bare-`inline` headers. Revertible; fallback
`--disable-libctf` (also covers a genuine C11 keyword `_Alignas`/`_Atomic` that CFLAGS can't fix).

**RESOLVED prior open question:** R9 DOES ship static `libstdc++.a`+`libsupc++.a` (build.ncl `cxx_libs`
glob, added 2026-07-01) → the top-level `AC_PROG_CXX -static` probe is de-risked; gold/gprofng disabled
makes C++ non-fatal anyway.

**Other walls:** Model-B regen (bison/flex parsers + pod2man man pages) — mtime-guard + LOUD stubs name
any miss [MED]; zlib table regen [LOW]; libctf musl qsort_r OK (musl-1.2.5 has it) [LOW]; plugins/LTO
[LOW].
**Flagged, NOT changed:** output globs (`usr/bin/*`, `usr/lib/*.a`, `usr/include/**`) MISS the native
tooldir `usr/x86_64-linux-gnu/{bin,lib/ldscripts}` + `usr/lib/ldscripts`. Not fatal (ld has built-in
emulation scripts; R11 finds as/ld on PATH) — but add `usr/x86_64-linux-gnu/**` to build.ncl if R11
probes the tooldir. `libiberty.a` won't install without `--enable-install-libiberty`.

**Deliverables:** `packages/stage0-binutils-2.41/{build.sh,build.ncl}` + `r10-binutils-2.41-preflight.md`.

---

## 3. B4 = glibc-2.42 hop — rung order, biggest risk, first move

> **UPDATE 2026-07-03:** the "which ≥12.1 gcc" question is RESOLVED — **R12 = gcc-15.2.0 direct** was
> built (musl, via `--with-native-system-header-dir=<musl-sysroot>/include`); the 5-major jump passed,
> so the gcc-12.4.0 fallback below is MOOT. Two of the "secondary risks" are now DECIDED, not open:
> Python trust posture = **image python 3.14.5, orchestration-only** (not a from-source rung); the
> musl-vs-glibc-TARGET question = **glibc** (conventional musl→glibc; the 368 pkg recipes change ZERO
> lines — only the 7 toolchain leaves' `replace_on_cycle` cycle-breaker + trust-config
> bootstrap_deps→bootstrap_artifacts move). glibc-2.42 itself is DESIGNED (separate pkg
> `glibc-bedrock-2.42`, cross-triple BUILD=x86_64-pc-linux-gnu HOST=x86_64-bedrock-linux-gnu so
> `cross_compiling=yes` skips AC_TRY_RUN while staying native, single-writer
> `/usr/lib/glibc-bedrock-2.42` sysroot) — **NOT yet built.** B4 rung sequence: R12(sealing) → glibc-2.42
> → B5 fixed-point (gcc-15.2.0 glibc-linked; binutils-2.46) → B6 differential-coreutils empty-diff → B7
> flip trust-config leaves to seed-rooted.

**HEADLINE (verified from the glibc-2.42 release announcement):** glibc-2.42 hard-requires
**GCC ≥ 12.1 and binutils ≥ 2.39** to build. Binutils is SATISFIED (R10 = 2.41). **The gcc-10.4.0 pivot
is BELOW the 12.1 floor → the pivot CANNOT build glibc directly** (fails at `configure`).

**Rung order:**
```
R11 gcc-10.4.0 (pivot, musl)
  ├─ linux-headers-6.12.43   (production, already mirrored, ~0-risk `make headers`; the cheap seam proof)
  └─ Rx modern gcc ≥ 12.1    (musl-linked, built BY R11)  ← the TRUE critical-path blocker
        └─ glibc-2.42        (built by Rx gcc + R10 binutils-2.41 + the headers; cold multi-pass bootstrap)
              └─ [B5] rebuild gcc-15.2.0 AGAINST glibc = self-hosting fixed point
              └─ [B4 cont.] re-root binutils-2.46.0 / gmp / mpfr / mpc onto glibc
```

**SINGLE BIGGEST RISK — the GCC floor.** It forces a new modern-gcc rung *before* glibc and **partially
inverts the north-star's B4-before-B5 order** ("build a modern gcc" must precede "build glibc"). The
pivot version (10.4, capped by 4.7.4's C++98 g++) and the glibc consumer (needs ≥12.1) pull opposite
directions → this rung was structurally inevitable.

**Secondary risks:**
- Cold **first-glibc multi-pass self-referential bootstrap** (install-headers → crt+libc → rebuild
  libgcc-against-glibc → full) — NOT the production one-shot `./configure && make`, which only works
  because `extract_to_root` already has a glibc in /usr. Production `packages/glibc/build.sh` is the
  step-5 shape ONLY; it is NOT a reusable B4 template.
- musl-vs-glibc **~50/50 /usr first-writer coin-flip** — mitigate with a single-writer
  `/usr/lib/glibc-bedrock-2.42` sysroot (same discipline R4b/R7 used for musl).
- **Python ≥ 3.4 enters the trusted closure for the first time** (the spine has none) — the sleeper
  dependency; decide the trust posture (from-source attested rung vs accepted builder-image tool) before
  building.
- localedef self-hosting + `-march=x86-64-v3` byte-determinism surface for the eventual B6 DDC gate.

**RED HERRING corrected:** `linux-4.14.336` (unmirrored) is irrelevant to B4 — it was only
live-bootstrap's deferred musl-spine pairing. B4 uses production linux-headers-6.12.43, already
mirrored, no gap.

**MIN-VIABLE gcc choice:** try **gcc-15.2.0 direct** (already mirrored, needed for B5 anyway) — fewest
rungs if the 5-major 10.4→15.2 jump survives; fallback **gcc-12.4.0** stepping stone (minimum jump
clearing 12.1, not yet mirrored) if it ICEs. The language gate is clear (gcc-10's C++14/17 satisfies
gcc-15's host requirement); the residual risk is the version jump, not capability.

**Deliverable:** `b4-glibc-2.42-scoping.md` (research-grade scoping, not a recipe).

---

## 4. Recommended next actions IN ORDER (after R9 vendors)

> **UPDATE 2026-07-03:** ALL FIVE steps below EXECUTED and SEALED (R9 vendored, R10 enqueued+sealed,
> gcc-10.4.0 mirrored, R11 enqueued+sealed as the pivot, linux-headers re-rooted). B3 CLOSED. The live
> frontier is now: seal R12=gcc-15.2.0 (rebuilding via the aliasing STOPGAP; durable fix = issue #14),
> then build the DESIGNED B4 glibc-2.42 rung. Step 5's "do NOT attempt glibc under gcc-10.4.0" is moot —
> the modern-gcc rung (R12) now exists. The list below is retained as history.

1. **Vendor R9** into the builder image (image-vs-pkgs-HEAD drift is the recurring foot-gun) and confirm
   the R5–R9 closure is a warm RemoteCache HIT.
2. **Enqueue R10 (binutils-2.41)** — READY now; independent of R11; the fastest verdict. Seal it so R11's
   build.ncl can swap its assembler from the R5 binutils-2.30 stand-in to `../stage0-binutils-2.41`.
3. **Mirror `gcc-10.4.0.tar.xz`** (re-verify sha `c9297d5bcd7c…`), swap R11's build.ncl CC-assembler
   import to R10, then **enqueue R11 (gcc-10.4.0)** LAST/serial with a raised timeout + 16G builder. This
   is the pivot: its wall #1 (R9-g++ C++11 capability) is the one only the cloud answers — plan for an
   R9.5=gcc-4.8.5 contingency (1-line CC-import swap) if a TU dies.
4. Once R11 seals: **re-root linux-headers-6.12.43** onto the pivot (literal glibc prerequisite, ~0
   codegen risk) to prove the B4 `extract_to_root` cutover seam cheaply — **while in parallel authoring +
   mirroring the modern-gcc-≥12.1 rung**, the actual critical-path blocker.
5. Do **NOT** waste a cycle attempting glibc-2.42 under gcc-10.4.0 — it fails the version check at
   `configure`. Author the glibc multi-pass (steps 1–4 production never needed) only after a ≥12.1 gcc
   exists, and settle the Python trust posture + musl-vs-glibc-target-stdenv decision first.

---

## Observations (beyond scope)

- **"os/generic is mandatory whenever we build libstdc++ on a -gnu triplet over musl"** deserves to be a
  standing bedrock reflex — it recurs on every future gcc rung until/unless we adopt the honest
  `*-linux-musl` triplet. That triplet switch is the cleaner long-term fix and is worth its own decision
  (it would also auto-select os/generic and musl specs, retiring fix (d) permanently).
- **The musl-vs-glibc TARGET stdenv is the single most consequential un-made decision** and it gates the
  entire glibc hop: a musl-based production target would delete B4's cold multi-pass bootstrap, the
  /usr coin-flip, the Python-in-closure expansion, and the modern-gcc-first inversion in one stroke.
  It should be decided deliberately, not defaulted into by momentum toward "rebuild production glibc."
  > **UPDATE 2026-07-03: DECISION MADE = glibc** (conventional musl→glibc; musl-as-target rejected — a
  > 368-pkg musl port = no rebuild confidence. The 368 recipes change ZERO lines; only the 7 toolchain
  > leaves' cycle-breaker + trust-config move).
- **Two "verify load-bearing claims" near-misses in one prep cycle** (R11's dropped fixes c+d; R10's
  under-rated gnu89 C-dialect wall) — both were drafts that "looked done" but would have failed the
  first cloud build for avoidable reasons. The pattern holds: the cloud is the arbiter of correctness,
  but a careful read of the *proven* prior rung's recipe catches the plumbing before you spend a cycle.
