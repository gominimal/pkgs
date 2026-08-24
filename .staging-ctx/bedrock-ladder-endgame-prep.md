# Bedrock-Ladder ENDGAME Prep — Master Synthesis (2026-07-01)

> **UPDATE 2026-07-03:** This prep doc is largely SUPERSEDED — the ladder advanced past every
> open question below. **B3 is CLOSED:** R6–R11 are all sealed (trust-grade SLSA-L4, attested in
> CS). The §2-Q3 "C++11 host RED SHOWSTOPPER" was resolved by taking Option 2 — the pivot
> retargeted gcc-10.5.0 → **gcc-10.4.0** (last C++98-bootstrappable, 4.7.4 builds it directly, zero
> extra gcc rung); the sealed pivot recipe lives at `packages/stage0-gcc-10.4.0/`, not the
> `stage0-gcc-10.5.0/` draft cited below (retired). R12 = gcc-15.2.0 is BUILT + FUNCTIONAL and
> re-sealing now (unblocked 2026-07-03 via a trust-neutral content-hash-aliasing stopgap on the
> shared `linux_headers` mirror slot; durable spec-qualified-mirror fix is issue #14, not yet
> deployed — do NOT re-attest stage0-linux-headers). The §3 "NO-GO" verdict is stale: B4 = the
> conventional musl→glibc "rebuild minimal" phase is DESIGNED (target glibc-2.42; 368 pkg recipes
> change ZERO lines, only the 7 toolchain leaves' cycle-breakers) but NOT built. Real remaining
> risk is toolchain CORRECTNESS (float/locale/TLS/IFUNC gate at R12 + B4), not ABI. Read the
> sections below as historical planning, not current state.

Consolidates four research passes: R10 (binutils-2.41), R11 (gcc-10.5.0), B4–B7 readiness,
and the wedge-detector fix. Source docs in this dir:
`r10-binutils-findings.md`, `r11-gcc-10.5-findings.md`, `b4-b7-readiness.md`,
`wedge-detector-fix.md`. Draft recipes live in
`packages/stage0-binutils-2.41/` and `packages/stage0-gcc-10.5.0/`
(both: build.ncl + executable build.sh + UNPINNED-ish stage0.answers — verified present).

**One-line state (2026-07-01, SUPERSEDED — see 2026-07-03 update above):** R6/R7/R8 sealed,
R9 building; R10 + R11 are now DRAFTED (not built). The R9→R11 ladder edge as specified is a
documented dead end (C++11 host gap) and must be amended before any R11 build cycle is spent.
We are NOT ready to rebuild production packages.
_(Current: B3 CLOSED — R6–R11 all sealed; the C++11 gap was cured by retargeting the pivot to
gcc-10.4.0; R12=gcc-15.2.0 built + re-sealing; B4 glibc phase designed, not built.)_

---

## (1) R10 + R11 recipe status + top predicted walls

### R10 — stage0-binutils-2.41 (DRAFTED, not built/enqueued)
Modern as/ld/ar/nm/objcopy/objdump/ranlib/readelf/strip, built BY R9 gcc-4.7.4, linked static
against musl-1.2.5. The gcc-built analog of R5 (which tcc built).

- **Source:** `gs://minimal-staging-archives/binutils-2.41.tar.xz`,
  sha256 `ae9a5789e23459e59606e6714723f2d3ffc31c03174191ef0d015bdf06007450`
  (confirmed by download+shasum).
- **Recon:** real TOP-LEVEL `configure` (drops R5's fragile per-subdir hand-loop — that was a
  tcc/i386 workaround, not needed under gcc); config.sub is 2023-06-23 → musl-native, **no
  config.sub swap**; ships gold/gprofng/libctf/libsframe (gold+gprofng disabled).
- **Recipe:** CC/CXX = R9's gcc-cc/gcc-cxx wrappers copied verbatim (all tcc-isms dropped — no
  @PLT strip, no asm-rm, real `ar`/`ranlib`); flags `--disable-shared --disable-nls
  --disable-werror --disable-gold --disable-gprofng --disable-plugins
  --enable-deterministic-archives --enable-install-libbfd`; `--prefix=/usr` + `make install
  DESTDIR=$OUTPUT_DIR` then `rm *.la`; Model-B mtime guard + loud regen stubs; as+ld smoke gate.

**R10 top predicted walls:**
1. **[HIGH] `as`/`ld`/`ranlib` not on PATH — the omitted R5 dep.** Task's stated dep list has NO
   binutils-2.30, but R9's gcc *shells out* to `as`/`ld` (gcc bundles neither) → first compile
   dies `as: command not found`. **Already fixed in the draft**: added `stage0-binutils-2.30` to
   build_deps (build_deps are not transitive) + a `command -v as` preflight in build.sh.
2. **[HIGH] Model-B parser/man regen** (ld/gas bison+flex `.y/.l`, pod2man/texi2pod man pages).
   2.41's generated set differs from 2.30; R5 did NO explicit mtime guard. Mitigated by the
   aggressive mtime guard; loud stubs name any miss to add to the touch-list.
3. **[MED] top-level `AC_PROG_CXX` probe.** The `-static` C++ probe depends on R9 actually having
   installed a static `libstdc++.a`. Open Q (see below). Fallback: `CXX=false` (gold/gprofng off
   makes a non-working C++ non-fatal).

**R10 load-bearing CORRECTION to the forward map:** the map's note that R10 should use R8's
"writable-staging-prefix idiom" is **WRONG for binutils** and would bake a `/build/...` path into
`ld`. That idiom is for library-only rungs whose build-time link reads a *dependency's installed*
`.la`; binutils' internal `.la` refs are relative/in-tree, and it installs prefix-baking BINARIES.
→ must use `--prefix=/usr` + DESTDIR (as R5/R6/R9 do). High confidence.

### R11 — stage0-gcc-10.5.0 = THE PIVOT (DRAFTED, not built; ladder edge is a dead end)
> **UPDATE 2026-07-03:** RESOLVED via §2-Q3 Option 2 — pivot retargeted to **gcc-10.4.0** (4.7.4
> builds it directly, no extra rung). Sealed recipe = `packages/stage0-gcc-10.4.0/`; the
> `stage0-gcc-10.5.0/` draft is retired. R11 is SEALED.
Seed-rooted modern C/C++ compiler. Intended builder = R9 g++; math = R8 gmp/mpfr/mpc; libc =
musl-1.2.5; assembler = R10 (R5 2.30 is the buildable stand-in until R10 seals).

- **Source:** `gcc-10.5.0.tar.xz`, sha256
  `25109543fdf46f397c347b52d8d7f298251990e99d47b6b6f0a643332d0d2beb` (matches forward-map prefix;
  SHA256 not independently locatable via public hash files — **re-verify against the mirror at pin
  time**: `gcloud storage cat gs://minimal-staging-archives/gcc-10.5.0.tar.xz | sha256sum`).
- **Recipe:** adapted from R9 — xz not bzip2; dual gcc-cc/gcc-cxx wrappers; `--disable-lto
  --disable-bootstrap --disable-multilib --enable-languages=c,c++ --without-isl
  --with-gmp/mpfr/mpc=/usr/lib/gcc-math`; fixincludes stub; Model-B mtime guard; outputs ADD
  `libstdc++.a`/`libsupc++.a` + C++ headers; C++14 libstdc++ smoke gate. A loud banner + a single
  `BUILDER_GCC` swap-point so the pivot can flip the moment the ladder is corrected.

**R11 top predicted walls:**
1. 🔴 **C++11 host pivot (see §2, Q3) — SHOWSTOPPER.** gcc-4.7.4 g++ cannot compile gcc-10.5's
   C++11 source; everything below is moot until the ladder edge is fixed.
2. 🟠 **Sequencing: R10 must be drafted+sealed first** (now drafted; still needs to build).
3. 🟡 **Model-B completeness on the larger 10.5 generated set** (more `.opt`→options.c, gengtype,
   flex/bison intl). Broaden touch-list per named miss; do a local configure-probe first.
4. 🟡 **libstdc++ static build against musl** — likely clean (Alpine precedent); verify outputs
   actually capture `libstdc++.a` + C++ headers.
5. 🟡 **C++ header search order in the CXX wrapper** — `-nostdinc` but KEEP `-nostdinc++`; verify
   `<cstdlib>`→`<stdlib.h>` resolves to musl, not glibc. Predicted iteration point.
6. 🟢 **OOM / wall-time** — bigger than R9; `-j1`, 16G, warm cache, queue last.

---

## (2) R11 critical-dependency VERDICTS

| Question | Verdict | Detail |
|---|---|---|
| **Q1: gmp/mpfr/mpc newer than R8?** | ✅ **NO — R8 satisfies with margin.** | gcc-10.5 minimums GMP≥4.3.2 / MPFR≥3.1.0 / MPC≥1.0.1; R8 ships 6.2.1 / 4.1.0 / 1.2.1. Reused verbatim via `--with-*=/usr/lib/gcc-math`. **No new math rung.** |
| **Q2: ISL/Graphite?** | ✅ **Avoidable — `--without-isl`, no ISL rung.** | ISL is Graphite-only and orthogonal to LTO; no top-level `--disable-graphite` exists in 10.5 → `--without-isl` is the correct switch (belt) + never mirror ISL (suspenders). Permanent bedrock stance. |
| **Q3: can gcc-4.7.4 g++ build gcc-10.5?** | 🔴 **NO — RED SHOWSTOPPER.** _(RESOLVED 2026-07-03: took Option 2 below — retargeted the pivot to gcc-10.4.0, the last C++98-bootstrappable gcc, which 4.7.4 builds directly. R11 sealed.)_ | gcc-10.5.0 REQUIRES a C++11 host (back-ported into the 10.5 point release: <10.5 → C++98, 10.5+ → C++11). gcc-4.7.4's C++11 is experimental/incomplete — missing inheriting constructors (`using Base::Base;`, added in 4.8) and full `thread_local`, exactly what 10.5's source uses. `--disable-bootstrap` makes it WORSE (host g++ compiles every `.cc`, no stage2 rescue). No `-std=` flag fixes a *capability* gap. |
| **Q4: extra musl seds?** | ✅ **Essentially NONE.** | siginfo→siginfo_t / ucontext→ucontext_t seds are NO-OPS on 10.5 (fixed upstream in gcc-8); kept only as harmless defensive guards. `--disable-libsanitizer/libssp/libgomp/libquadmath` amputates Alpine's musl patch surface. Add targeted seds reactively only if a configure probe misfires. |

### Q3 FIX — pick one (both drafted-for via the one-line `BUILDER_GCC` swap-point):
- **Option 1 — insert an intermediate rung R9.5 = gcc-4.8.5 (or 4.9.4)** built BY 4.7.4 (4.8.x is
  `<10.5` → bootstraps from C++98 → 4.7.4 CAN build it). Then R11 is built by 4.8.5's g++ (the
  documented ≥4.8.3 minimum). Ladder-correct; cost = +1 gcc rung.
- **Option 2 (recommended if a C++14 pivot is acceptable) — retarget the pivot to gcc-10.4.0.**
  10.4 is the last C++98-bootstrappable gcc → 4.7.4 builds it DIRECTLY, ZERO new gcc rung. Cost =
  mirror `gcc-10.4.0.tar.xz` (NOT currently in the mirror — only 10.5.0 is) + re-pin. Lowest
  effort; 10.4 ≈ 10.5 minus bugfixes.

---

## (3) B4–B7 "ready to rebuild minimal?" — GO/NO-GO + first post-R11 step

### VERDICT: 🔴 **NO-GO.** Not ready to rebuild production packages now.
> **UPDATE 2026-07-03:** STALE. B3 CLOSED (R6–R11 all sealed); R12=gcc-15.2.0 built + re-sealing.
> B4 = the conventional musl→glibc "rebuild minimal" phase is now DESIGNED (target glibc-2.42; the
> 368 production pkg recipes change ZERO lines — only the 7 toolchain leaves' cycle-breakers +
> relocating trust-config bootstrap_deps→bootstrap_artifacts), but NOT yet built. The B4/B5 detail
> below is superseded by the current B4 plan (glibc first, then B5 gcc-15.2.0 glibc-linked fixed
> point). Remaining risk is toolchain CORRECTNESS, not ABI.
Hard gate: **B3 (the lower spine) is unfinished.** R6/R7/R8 sealed; R9 building; R10 + R11 now
drafted but NOT built/sealed. B4 (Bridge) re-roots the prebuilts ONTO the R11 pivot, so B4
literally cannot start until R11 seals — and R11 can't build until the C++11 ladder gap (§2 Q3)
is closed. The toolchain we'd rebuild *with* does not yet exist in seed-rooted form.

**Pivot claim CONFIRMED, with a precision fix to "B4 re-roots the 7 prebuilts":**
- **B4** re-roots **6** of 7 (linux-headers, binutils, glibc, gmp, mpfr, mpc) onto the R11 pivot.
- **B5** handles the **7th** — rebuilds production **gcc-15.2.0** against from-source glibc (the
  self-hosting fixed point; **intentionally NOT byte-identical** to the prebuilt).
- **B7** is the cutover: drop the 7 prebuilt-blob inputs, stop `extract_to_root`-ing them, collapse
  the trust floor to the 229-byte seed. (368 production pkgs re-attested; the `extract_to_root`
  input is the single well-understood cutover seam.)

### SINGLE MOST IMPORTANT ACTION AFTER R11 SEALS:
**Prove the R11 gcc-10.5.0 pivot can build glibc-2.42 from source.** The whole spine is musl-only;
glibc has NEVER been built anywhere in the spine — this is the load-bearing musl→glibc hop.
Concrete order:
1. **linux-headers-6.12.43 first** (mechanical, ~0 codegen risk — `make headers` + copy,
   compiler-agnostic). Proves the bridge plumbing cheaply; it's the prerequisite glibc needs.
2. **glibc-2.42 = the load-bearing net-new hop.** Build with R11 gcc-10.5.0 + R10 binutils-2.41 +
   from-source linux-headers → first seed-rooted glibc sysroot. Must precede re-rooting
   binutils/gmp/mpfr/mpc (those must be built against the glibc ABI to match production).
3. Then re-root gmp/mpfr/mpc + binutils against the from-source glibc (recipe-shaped version bumps
   to 6.3.0/4.2.2/1.4.0 + 2.46.0 + the glibc-sysroot swap).

### Ready now vs the gap
- **Ready:** attestation/CHAIN_ENFORCE/dual-sign (ECDSA P-256 + ML-DSA-65)/byte-identical repro
  machinery proven through R8; sealed gcc-4.0.4/musl-1.2.5/gmp-mpfr-mpc; gcc-cc wrapper +
  single-writer musl-bedrock sysroot; RemoteCache; production recipes already build from-source
  (only the CC changes at B5).
- **Gap:** R9→R10→R11 must seal; glibc-from-source never attempted; no DDC-capable diverse builder
  for B6 (single builder in us-west1-c today).

### B4–B7 top risks
1. **musl→glibc B4 hop** — must PROVE (not assume) gcc-10.5 clears glibc-2.42's minimum-compiler
   bar; recent glibc raises its required-GCC floor. If 2.42 needs newer than 10.5, B4 needs a
   hidden R12 or B5's gcc-15 must land before the glibc re-root. Also re-introduces the ~50/50
   glibc-vs-musl `/usr` first-writer pollution coin-flip.
2. **B5 5-major gcc jump 10.5→15.2** in one hop against from-source glibc — untested; an
   intermediate gcc (13.x) may be needed.
3. **B5 fixed point intentionally NOT byte-identical** to the prebuilt (different compiler → different
   bytes) — any repro/DDC gate must accept this or it false-fails.
4. **DDC hardware (B6)** — infra/procurement dependency (diverse silicon in CS), on the critical
   path for the *trust* claim.
5. **B7 368-pkg re-attestation cost** — hours-to-days of CS compute; depends on RemoteCache staying
   warm across cutover.
6. **linux-headers/kernel TCB stays trusted, not bootstrapped** — honest scope boundary; attested-
   as-bytes + re-rooted, never source-bootstrapped. Not a blocker; the earned claim must not overstate.

---

## (4) Wedge-detector fix (DESIGN ONLY — no code edits yet)
> **UPDATE 2026-07-03:** This section is design-only; whether the `MAX_ACTIVE_SECS` cap actually
> landed in `crates/orch/src/main.rs` is NOT confirmed from current ground truth — verify against
> the deployed builder before relying on it.

**Bug (2026-07-01):** a task stayed `active` 125 min with a FRESH heartbeat (builder's 60s
heartbeat kept rewriting status.json, status-age oscillated 0–166s) while making NO progress — a
network-stalled attestation/chain-probe walk. Never auto-recovered; needed manual `orch drop
--from active` + re-enqueue. Root cause: the Active-arm auto-recovery in `watch_and_retry_lottery`
(`crates/orch/src/main.rs`) fires on **status-age alone** (`a > STALE_STATUS_SECS`, 1800s,
main.rs:6712) — a fresh-heartbeat wedge keeps `a` small forever, so the guard never trips.

**Fix — a second, generous discriminator that climbs regardless of heartbeat freshness:**
- **Threshold:** `MAX_ACTIVE_SECS = 6000` (100 min). Justification: this watch is opt-in per
  `--retry-on-lottery` (bedrock rungs only — bun ~88m enqueues WITHOUT the flag, out of scope); the
  in-scope worst case is gcc cold closure ~45 min → 100 min is >2x, above the code's own "90-min
  fresh-heartbeat is healthy" line, below the 125-min wedge.
- **Insertion point:** new const after `STALE_STATUS_SECS` at main.rs:6606; refactor the Active-arm
  status read at main.rs:6703-6708 to compute `active_over_cap = (now - status.started_at) >
  MAX_ACTIVE_SECS` (`started_at` written once at claim, carried unchanged through heartbeats).
- **Core condition (main.rs:6712):** broaden to
  `Some(a) if a > STALE_STATUS_SECS || active_over_cap =>`, with a `reason` string distinguishing
  "builder status stale {a}s" vs "active {m}m with a FRESH heartbeat but no progress".
- **Reuse:** piggybacks on the existing drop + `wedge_recoveries += 1` + `enqueue` body, still
  bounded by `WEDGE_RECOVERY_CAP` (3). Log lines at 6714/6743 reworded to use `reason`. Resets per
  claim (enqueue clears Status → recovered task reads None → can't instantly re-trip).
- **Risk/mitigation:** false-killing a legit >100-min build re-runs that pkg's OWN compile from
  scratch (RemoteCache skips deps, not intra-build steps) — mitigated by scope + generous cap +
  WEDGE_RECOVERY_CAP + an optional `--max-active-mins <N>` override (recommended additive follow-up).
- **Honest gap:** a true long-active-AND-no-progress AND-gate is NOT buildable today — queue_mode
  writes `phase="building"` as a constant (verified; struct doc's `"building #44 python"` is
  aspirational), so no mid-build progress signal exists. The real long-term fix is a builder-side
  monotonic progress token in `Status`; the scoped active-time cap is the safe cheap-now backstop.
  Separately, the hung chain-probe HTTP walk ideally gets a call-site timeout (root-cause fix) so
  the build fails cleanly rather than relying on the operator watch hours later.

---

## Cross-cutting corrections & stale-doc flags (all four agents converged here)
- **`bedrock-ladder-R4-R11-2026-06-25.md` does not exist.** The task prompt cites a stale filename;
  actual detail lives in `bedrock-r8-r11-forward-map.md` + `bedrock-r7-gcc-cc-wrapper.md` + the
  north-star B3 row. Reconcile so the "detailed spec" reference doesn't rot.
- **Forward map / north-star lag reality:** B3 row still reads "R7–R11 remain" and forward-map
  header says "R7 in flight," but R7/R8 are sealed and R9 is building. One-line status bump needed.
- **Forward map OMITS the C++11 host constraint** and lists R9→R11 as a clean edge — it is a
  documented NO. Amend to insert the intermediate rung OR retarget to 10.4.0 BEFORE spending an R11
  cycle. This is the single most important correction for B3.
- **Forward-map "writable-staging-prefix idiom for R10" is wrong** — see R10 correction in §1.
- **Audit R9's outputs:** its captured set (`usr/bin/*` + `usr/libexec/**` + `usr/lib/gcc/**`) looks
  like it DROPS `libstdc++.a` + the C++ headers. If so, R9's g++ is unusable as R11's builder even
  after the C++11 gap is closed (and R10's C++ probe `-static` link would fail). Verify against what
  `make install` actually wrote before building R10/R11.
