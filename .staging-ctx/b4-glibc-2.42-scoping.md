# B4 — glibc-2.42 hop, scoping (research-grade, NOT a build recipe)

> **UPDATE 2026-07-03 (superseded):** This scoping doc is superseded by
> `b4-glibc-buildplan-2026-07-02.md` (which supersedes the open questions here) and the current recipe
> `b4-glibc-recipe-design-2026-07-03.md`. Ground-truth deltas since writing:
> **B3 is CLOSED** (hex0→gcc-10.4.0, all rungs sealed/L4). **R12 = gcc-15.2.0 BUILT + FUNCTIONAL** —
> the direct 10.4→15.2 5-major jump PASSED (Open Q1 resolved: 15.2-direct chosen, no stepping stone),
> built on musl via `--with-native-system-header-dir`. R12's seal was blocked by a content-hash
> aliasing bug (stage0 ≡ production linux_headers share artifact-sha 083cdb → poisoned `.intoto`);
> unblocked 2026-07-03 via a trust-neutral stopgap (durable spec-qualified-mirror fix = issue #14,
> review-gated). R12 is re-sealing (rebuild-from-cosigned-image in progress); **not yet sealed**.
> **Target stdenv DECIDED (operator 2026-07-02): glibc, the conventional musl→glibc path** — musl-as-target
> REJECTED (Open Q4 closed). Killer finding since: the 368 production pkg recipes change ZERO lines;
> only the 7 toolchain leaves change (url+sha in each `replace_on_cycle` breaker + bootstrap_deps→
> bootstrap_artifacts relocation). B4 glibc-2.42 is DESIGNED, NOT yet built.

Written 2026-07-02. The first concrete B4 step after R11 (the gcc-10.4.0 pivot) seals: introduce
**glibc** — the load-bearing musl→glibc transition the production toolchain links. The entire bedrock
spine R4–R11 is **musl-only**; glibc has never been built anywhere in it.

Grounded against: `docs/north-star-bedrock-attested-bootstrap.md` (B4 Bridge / B5 / B7),
`.staging-ctx/b4-b7-readiness.md`, `.staging-ctx/bedrock-ladder-endgame-prep.md`,
`.staging-ctx/bedrock-r8-r11-forward-map.md`, the production recipes
`packages/{glibc,linux_headers,gcc,binutils}/`, and `trust-config.json` (the 7 prebuilt leaves).
The one **new external fact** driving this doc: glibc-2.42's build-tool minimums, verified against the
glibc 2.42 release announcement (see Open Questions / sources).

---

## 0. The headline finding (this reorders the ladder)

**glibc-2.42 hard-requires GCC ≥ 12.1 and GNU Binutils ≥ 2.39 to BUILD** (glibc 2.42 release
announcement, 2025-07: *"GCC 12.1 or later is now required to build the GNU C Library"* +
*"GNU Binutils 2.39 or later is now required"*).

Consequences, checked against our sealed/drafted rungs:
- **Binutils: SATISFIED.** R10 = binutils-2.41 (≥ 2.39 ✓). No new binutils rung is needed to *build*
  glibc. (Re-rooting production binutils-2.46.0 is a separate, later B4 step.)
- **GCC: NOT satisfied by the pivot.** R11 = **gcc-10.4.0** — *below* the 12.1 floor. **The pivot
  cannot build glibc-2.42.** The b4-b7-readiness doc flagged this only as a hypothetical ("if 2.42
  needs newer than 10.5…"); it is now **confirmed fact**, and it partially inverts the north-star's
  B4-before-B5 ordering: a **modern gcc ≥ 12.1 must be built before glibc** — i.e. B5's "build a
  modern gcc" work moves *ahead of* B4's glibc, not after it.

So the readiness doc's headline "prove the pivot can build glibc-2.42" is **retired** — we already know
the answer is no. The real first question is: *which* gcc ≥ 12.1 rung do we stand up, and how.

---

## 1. Rung order for the glibc hop

```
R11  gcc-10.4.0        (pivot, musl-linked)                         ← B3 close (prerequisite)
      │
      ├─ linux-headers-6.12.43   (production; `make headers` + copy; compiler-agnostic; ~0 codegen
      │                           risk; already mirrored). The cheap plumbing proof + glibc's
      │                           prerequisite (/usr/include/linux + /usr/include/asm).
      │
      └─ Rx  modern gcc ≥ 12.1   (musl-linked; built BY R11's g++)  ← the TRUE first blocker
              │                    recommend: production gcc-15.2.0 on musl (needed for B5 anyway);
              │                    fallback: gcc-12.4.0 → 13.x stepping stones if the 5-major jump fails
              ▼
        glibc-2.42     (built by Rx gcc≥12.1 + R10 binutils-2.41 + linux-headers-6.12.43)
              │          the load-bearing net-new hop; cold FIRST-glibc multi-pass bootstrap
              ▼
        [then B5]   rebuild gcc-15.2.0 AGAINST the from-source glibc = self-hosting fixed point
        [then B4 cont.]  re-root binutils-2.46.0 / gmp-6.3.0 / mpfr-4.2.2 / mpc-1.4.0 onto glibc
```

Two-line summary of order: **linux-headers-6.12.43 → modern-gcc(≥12.1) → glibc-2.42**, with
linux-headers being throwaway-cheap and the modern-gcc rung being the actual gate.

Note the distinction the north-star blurs: the gcc we build to *make* glibc is **musl-linked**
(a compiler's own libc ≠ the libc it targets — the forward-map's core idea, unchanged here). B5's
gcc-15.2.0 is the *glibc-linked* rebuild for the fixed point. If we use gcc-15.2.0 source for both,
we compile it twice (once on musl to birth glibc, once on glibc for the fixed point) — clean, and it
proves the compiler both ways.

---

## 2. What building glibc-2.42 from the pivot actually requires

### 2a. Build-tool minimums (glibc 2.42 INSTALL "Tools for Compilation")
| Tool | glibc-2.42 minimum | Bedrock status |
|---|---|---|
| **GCC** | **≥ 12.1** | ❌ pivot is 10.4.0 → needs a new gcc rung (§1) |
| **GNU Binutils** | **≥ 2.39** | ✅ R10 binutils-2.41 |
| **GNU make** | ≥ 4.0 | ✅ spine `make` (verify ≥4.0) |
| **GNU awk** | required | ✅ spine `gawk-bootstrap` |
| **Python** | **≥ 3.4** (hard since glibc 2.29) | ⚠️ **NOT in the spine closure** — see §3 hard part #4 |
| sed / grep / gzip+xz | required | ✅ spine has all |

### 2b. Kernel headers — use PRODUCTION 6.12.43, not the deferred 4.14.336
- The spine's R7 musl was *paired* with `linux-4.14.336` in live-bootstrap's i386 recipe, but that was
  **deferred and never built** (musl compiles standalone; `stage0-musl-1.2.5/build.ncl` TODO says so).
  `linux-4.14.336` being "not yet mirrored" is a **red herring for B4** — it was only ever the musl
  spine's pairing, and at 4.14 it is arguably *too old* for glibc-2.42's headers anyway.
- **B4 should build production `linux-headers-6.12.43`** (already mirrored:
  `gs://minimalmertic-hermetic-mirror/sha256/0fcb…/linux-6.12.43.tar.xz`, sha `0fcbb…`; trivial
  `make headers`). This matches production exactly, sits comfortably above any glibc-2.42 header
  minimum, and its `--enable-kernel=6.1` (production runtime floor) is unaffected. **No kernel-header
  mirroring gap exists for B4.**

### 2c. The compiler must target glibc, but glibc provides its own headers (the self-referential part)
The bedrock gcc's are **musl-targeting** via the `gcc-cc` sysroot wrapper (`-nostdinc -isystem
$SR/include -B/-L $SR/lib -static`). To build glibc, that wrapper's sysroot must flip to a
**glibc** sysroot — which does not exist yet. glibc famously **builds against itself**: you need
glibc's headers to build the full compiler runtime, and the compiler to build glibc. In production
today this is invisible because `extract_to_root` has already put a glibc **and** gcc-15.2.0 in `/usr`
before `packages/glibc/build.sh` runs — so production's build is a *native rebuild atop an existing
glibc*, **not** a cold bootstrap. B4 has no pre-existing glibc → B4's glibc build is a genuinely
different, harder shape than the production recipe. See §3 hard part #1.

---

## 3. The hard parts (why this is the single highest-risk B4 step)

1. **Cold first-glibc = a multi-pass self-referential bootstrap (the crux).** With no glibc in the
   sandbox, the min-viable path is the classic LFS / crosstool-NG dance, not the one-shot production
   `./configure && make`:
   1. binutils-2.41 (have it) + a modern gcc ≥ 12.1, musl-linked (stage-1 compiler).
   2. `make install-headers` — install glibc headers (needs only linux-headers + compiler; no libc link).
   3. glibc stage-1 — build `crt{1,i,n}.o` + `libc` against linux-headers (compiler in "target libc
      not yet present" mode).
   4. **rebuild the compiler's `libgcc` against the fresh glibc** — the real coupling point: glibc's
      shared objects link libgcc, and our libgcc was built against **musl**. libgcc is *mostly*
      libc-agnostic, but `libgcc_s` unwinding + TLS can couple to the libc → a musl-built libgcc may
      not cleanly link into glibc outputs. Two-pass (rebuild libgcc on glibc) is the safe resolution.
   5. glibc final — full rebuild against the stage-2 compiler.
   The production `packages/glibc/build.sh` (a plain `./configure --prefix=/usr … && make`) is the
   *step-5 shape only* — B4 must author steps 1–4 that production never needed.

2. **musl-vs-glibc in one sandbox = the documented ~50/50 `/usr` first-writer coin-flip.** minimal's
   sandbox `/usr` is an *unordered, first-writer-wins* merge (see memory
   `minimal_rootfs_nondeterministic_pollution` / the R4b diagnosis). A musl `/usr/lib/musl-bedrock-1.2.5`
   sysroot and a fresh glibc `/usr/lib/libc.a`+headers coexisting is exactly the pollution class that
   broke s4. **Mitigation is already battle-tested**: publish glibc as a **single-writer versioned
   sysroot** (e.g. `/usr/lib/glibc-bedrock-2.42`) and compile `-nostdinc` against the clean tree,
   the same discipline R4b/R7 used for musl.

3. **GCC version floor (§0) forces a modern-gcc rung + possibly a stepping stone.** gcc-10.4.0's g++
   provides C++14/17, which *satisfies gcc-15.2.0's host-language requirement* (gcc-15 needs a C++14
   host) — so the **language** gate is clear. The residual risk is the **5-major version jump**
   (10.4 → 15.2) that GCC normally does adjacent-version; if it miscompiles/ICEs, insert gcc-12.4.0
   (last 12.x, clears the 12.1 floor at minimum jump) or gcc-13.x as a stepping stone. This is a
   version-jump risk, not a capability gap.

4. **Python enters the trusted build closure for the first time.** glibc has required **Python ≥ 3.4**
   since 2.29 (generated-file scripts). The spine closure (make/sed/grep/gawk-bootstrap/coreutils/tar)
   has **no Python**. B4-glibc therefore pulls Python into the closure — either a from-source attested
   Python rung (heavy: Python's own toolchain closure) or an accepted builder-image tool (weakens the
   seed-rooting for this hop). This is a real, under-appreciated dependency-graph expansion; decide the
   trust posture before the build.

5. **localedef self-hosting wrinkle.** Production `glibc/build.sh` runs `localedef … en_US` at the end
   — which needs a *working* glibc at build time. In a cold first-glibc build the just-built
   `localedef` must run against the just-built glibc; workable (it's self-hosting) but an extra moving
   part vs the production recipe, and a determinism surface (locale archive byte-stability).

6. **`-march=x86-64-v3` + determinism.** Production glibc builds `-march=x86-64-v3` (AVX2-class). Fine
   on modern CS silicon, but pins a microarch floor and is a byte-determinism variable for the
   eventual B6 DDC gate (must be identical across the a/b builders).

---

## 4. Minimum-viable path (fewest rungs that clears every floor)

1. **linux-headers-6.12.43** re-rooted onto the pivot toolchain (or even built with prebuilt binutils —
   it's compiler-agnostic). ~0 risk. Proves the B4 `extract_to_root` bridge seam end-to-end cheaply.
2. **A modern gcc ≥ 12.1, musl-linked, built by R11 gcc-10.4.0.** Recommended target: **production
   gcc-15.2.0** (we need it for B5 regardless, so building it now on musl is not a throwaway rung).
   Fallback if the 5-major jump fails: **gcc-12.4.0** (minimum jump that clears the 12.1 floor), climb
   to 15.2 later. Mirror-check: gcc-15.2.0 source is already mirrored (production uses it); gcc-12.4.0
   is NOT yet mirrored (would need `gcloud storage cp` + pin).
3. **glibc-2.42**, multi-pass (§3 #1), built by the step-2 gcc + R10 binutils-2.41 +
   step-1 linux-headers, published as a single-writer `/usr/lib/glibc-bedrock-2.42` sysroot (§3 #2).
4. Only then: **B5** (rebuild gcc-15.2.0 against the from-source glibc → self-hosting fixed point) and
   the rest of **B4** (re-root binutils-2.46.0 / gmp-6.3.0 / mpfr-4.2.2 / mpc-1.4.0 onto glibc — these
   must be built against the glibc ABI, not musl, to match production leaves).

**Recommended concrete FIRST MOVE after R11 seals:** re-root **linux-headers-6.12.43** onto the pivot
(the literal prerequisite, ~0 codegen risk, already mirrored) to prove the bridge/`extract_to_root`
cutover seam works end-to-end — **while in parallel** authoring + mirroring the **modern-gcc-≥12.1
rung**, because *that*, not glibc, is the true critical-path blocker this scoping uncovered. Do **not**
spend a cycle attempting glibc-2.42 under the gcc-10.4.0 pivot; it will fail the version check at
`configure`.

---

## 5. How this connects to B7 (the cutover)

B7 replaces the **7 trusted prebuilt leaves** (`trust-config.json`: gcc-15.2.0, glibc-2.42,
binutils-2.46.0, gmp-6.3.0, mpfr-4.2.2, mpc-1.4.0, linux-headers-6.12.43) with from-source attested
rungs. **glibc is the keystone the production toolchain *links*** — production gcc-15.2.0 and every
production package is glibc-ABI. The single cutover seam is the builder's `extract_to_root` of the 7
prebuilt tarballs into `/usr` (wired because cc1's hard-coded `/usr/lib/gcc/<triple>/<ver>/cc1` paths
must sit at `/usr`). B4 produces from-source replacements for those tarballs; **B7 flips the input
from prebuilt-blob to from-source-sealed and deletes the `bootstrap_deps` entries**, collapsing the
trust floor to the 229-byte seed. Ordering within the 7 at B7: glibc + gcc are co-dependent (gcc-15
built against glibc, glibc built against gcc≥12.1), so they cut over as a matched set; linux-headers
+ binutils + gmp/mpfr/mpc are leaves off that set.

**Honest scope boundary (unchanged):** linux-headers is only *attested-as-bytes + re-rooted*, never
source-bootstrapped — the kernel/firmware TCB stays trusted (the same boundary Helsing draws). The
earned claim must not overstate this.

---

## 6. Open questions (decide before the first build cycle)

1. **Which gcc rung for the ≥12.1 requirement — gcc-15.2.0 direct (5-major jump, but needed anyway)
   or gcc-12.4.0 stepping stone (safer jump, extra rung, not yet mirrored)?** Recommend probing the
   direct 10.4→15.2 build first; it's the fewest-rungs path if it survives.
   > **RESOLVED 2026-07-03:** 15.2.0-direct SUCCEEDED — R12 built + functional, the 10.4→15.2 jump
   > PASSED. No stepping stone needed.
2. **Python trust posture (§3 #4)** — from-source attested Python rung (heavy closure) vs. accepted
   builder-image tool (weakens seed-rooting for the glibc hop). This is the biggest un-scoped
   dependency-graph decision.
3. **Two-pass vs. shortcut for libgcc (§3 #1 step 4)** — is a musl-built libgcc actually ABI-safe to
   link into glibc outputs, letting us skip the libgcc rebuild? Cheap to probe; if yes, the multi-pass
   collapses toward the production one-shot shape.
4. **Target stdenv decision (flagged in b4-b7-readiness Observations, still un-made):** is B4 truly
   "rebuild production glibc-2.42," or is a musl-based production stdenv on the table? A musl target
   would delete this entire hop and its risk surface. This is the single most consequential un-made
   decision and it gates everything above.
   > **DECIDED 2026-07-02 (operator):** glibc — the CONVENTIONAL musl→glibc path. Musl-as-target
   > REJECTED (a 368-pkg musl port = no rebuild confidence). This hop stays.
5. **Exact glibc-2.42 `make` and `bison` minimums** — verify against the real INSTALL (the sourceware
   copy is behind an Anubis anti-bot wall; the GCC/binutils minimums here are from the release
   announcement, which is authoritative; the make/awk/Python minimums are from glibc's long-standing
   INSTALL and should be re-confirmed at pin time).
6. **Determinism/DDC (B6):** `-march=x86-64-v3` + localefile byte-stability + glibc's `--build-id=none`
   (production already sets `-Wl,--build-id=none`) must all be pinned before a true a/b bit-identical
   gate — no diverse builder exists yet.

## Observations (beyond scope, flagged per instructions)

- **The GCC-12.1 floor changes the north-star's B4/B5 ordering.** The roadmap lists B4 (bridge, incl.
  glibc) *before* B5 (rebuild gcc-15). But glibc-2.42 needs gcc ≥ 12.1, and the only from-source modern
  gcc we can produce is by climbing to (at least) gcc-12/15 *first*. So "build a modern gcc" must
  precede "build glibc." Worth a one-line amendment to the B4/B5 rows so the next reader isn't
  surprised at the pivot.
- **The pivot version (10.4.0) was chosen to satisfy the *R11 builder* constraint (4.7.4's C++98-only
  g++), not the *glibc consumer* constraint.** Those two constraints pull opposite directions:
  4.7.4 caps the pivot at ≤10.4 (C++98-bootstrappable), while glibc-2.42 demands ≥12.1. The pivot was
  never going to be able to build glibc directly — a modern-gcc rung between the pivot and glibc was
  structurally inevitable, independent of any single version choice.
- **Production `packages/glibc/build.sh` is NOT a reusable template for B4.** It is the *native-rebuild*
  shape (glibc already in `/usr` via extract_to_root). Anyone reaching for it as the B4 recipe will
  miss the cold multi-pass bootstrap entirely. The b4-b7-readiness sketch ("build it with R11 …") reads
  as if the production recipe drops in — it does not.
- **Python is the sleeper dependency.** Every prior spine rung lived on a tiny hand-tools closure;
  glibc silently drags in a Python interpreter. This is the first place the bedrock closure stops being
  "a handful of C tools" — worth a deliberate decision rather than discovering it at build time.

## Sources
- glibc 2.42 release announcement (build-tool minimums): https://lists.gnu.org/archive/html/info-gnu/2025-07/msg00011.html
- glibc 2.42 coverage (GCC 12.1 / binutils 2.39 confirmation): https://linuxiac.com/glibc-2-42-lands-with-new-features-cve-fixes-and-performance-gains/
- "Require GCC 6.2 or later to build glibc" (historical floor context): https://sourceware.org/pipermail/libc-alpha/2019-January/101010.html
- glibc NEWS (master): https://github.com/bminor/glibc/blob/master/NEWS
</content>
