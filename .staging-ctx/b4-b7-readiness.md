# B4–B7 Readiness — "Are we ready to rebuild minimal's production packages on the from-source bedrock toolchain?"

Written 2026-07-01. Grounded against `docs/north-star-bedrock-attested-bootstrap.md`,
`trust-config.json`, the production toolchain recipes in `packages/{gcc,glibc,binutils,gmp,mpfr,mpc,linux_headers}/`,
the sealed `stage0-*` recipes, and `.staging-ctx/bedrock-{r7-gcc-cc-wrapper,r8-r11-forward-map}.md`.

## (a) VERDICT — NO-GO (yet). Not ready to rebuild production packages now.

> **UPDATE 2026-07-03:** This verdict is OBSOLETE. **B3 IS CLOSED** — R5–R11 are all
> SEALED (trust-grade SLSA-L4, attested in Confidential Space) and R12 (gcc-15.2.0) is
> BUILT + functional (sealing now; unblocked via a content-hash-aliasing stopgap, durable
> fix issue #14 pending — do NOT re-attest stage0-linux-headers). **THE PIVOT is gcc-10.4.0
> (R11), NOT gcc-10.5.0.** B4 = glibc-2.42 (the conventional musl→glibc path) is DESIGNED but
> NOT built. See the "CURRENT BEDROCK LADDER STATE" note in MEMORY / north-star B3 row.
> The rung-state bullets and pivot-version below are left as written for history.

**Hard gate: B3 (the lower spine) is not finished.** As of today:
- R6 gcc-4.0.4, R7 musl-1.2.5, R8 gmp/mpfr/mpc — **SEALED**.
- R9 gcc-4.7.4 — **building now** (recipe exists: `stage0-gcc-4.7.4/{build.sh,build.ncl,stage0.answers}`, not sealed). *(UPDATE 2026-07-03: SEALED.)*
- R10 binutils-2.41 — **no recipe exists yet.** *(UPDATE 2026-07-03: authored and SEALED.)*
- R11 gcc-10.5.0 (THE PIVOT) — **no recipe exists yet.** *(UPDATE 2026-07-03: authored and SEALED — the pivot is gcc-**10.4.0**, not 10.5.0.)*

B4 (Bridge) is defined in the north-star as re-rooting the prebuilts **onto the from-source pivot**, and
that pivot **is** R11 gcc-10.5.0. You cannot start B4 until R11 seals. Two full rungs (R10, R11) plus the
in-flight R9 stand between "now" and "B4 can begin." So the honest answer to "rebuild production packages
now" is **no** — the toolchain we'd rebuild them *with* does not yet exist in seed-rooted form.
*(UPDATE 2026-07-03: R9/R10/R11 all sealed; the pivot is gcc-10.4.0; B4 can now begin.)*

**On the pivot claim — CONFIRMED, with one precision fix.**
- *Confirmed:* R11 gcc-10.5.0 is explicitly "the ★ PIVOT that closes B3 → seed-rooted modern C/C++."
  gcc-10.5 was chosen deliberately as the *modern-C/C++* pivot: modern enough (C++14/17 host) to be the
  bootstrap compiler for both from-source glibc and the production gcc-15.2.0, unlike the C89-era gcc-4.0.4.
- *Precision fix to the task framing "B4 re-roots the 7 prebuilts":* the docs split the 7 across three
  milestones, not one:
  - **B4** re-roots **6** of the 7 (linux-headers, binutils, glibc, gmp, mpfr, mpc) onto the R11 pivot.
  - **B5** handles the **7th** — it rebuilds production **gcc-15.2.0** against the from-source glibc (the
    self-hosting fixed point; explicitly *not* byte-identical to the prebuilt, since a different compiler built it).
  - **B7** is the actual *cutover*: physically drop the 7 prebuilt-blob inputs from `bootstrap_deps` /
    stop `extract_to_root`-ing them, and collapse the trust floor to the 229-byte seed.
  So gcc-10.5.0 is the pivot everything is *built by*; it is not itself one of the production leaves being
  replaced (production ships gcc-15.2.0).

## (b) The concrete B4 FIRST STEP once R11 seals

> **UPDATE 2026-07-03:** R11 has sealed. Every "gcc-10.5.0" below is the pivot; the actual
> pivot version is **gcc-10.4.0**. The musl→glibc target is DECIDED = glibc (conventional path);
> the killer finding is that the 368 pkg recipes change ZERO lines — only the 7 toolchain leaves
> change (swap each leaf's `replace_on_cycle` prebuilt cycle-breaker url+sha, and relocate 7
> trust-config `bootstrap_deps`→`bootstrap_artifacts`). B4 rung sequence:
> R12 gcc-15.2.0 (needed — glibc-2.42 hard-requires GCC ≥12.1, confirming risk #1's "hidden R12")
> → glibc-2.42 cold self-referential bootstrap → B5 fixed-point → B6 differential-coreutils → B7 flip.

The production world is **glibc** (glibc-2.42); the entire bedrock spine R4–R11 is **musl** (musl-1.2.5).
B4's "one net-new hop" is re-introducing glibc under the seed-rooted pivot. Concrete order:

1. **linux-headers-6.12.43 first (mechanical unblocker, ~0 codegen risk).** `packages/linux_headers/build.sh`
   is just `make headers` + copy — compiler-agnostic, no libc/ABI dependency. Re-rooting it onto the pivot is
   trivial and it is the prerequisite glibc needs (`/usr/include/linux` + `/usr/include/asm`, per the
   trust-config glibc rationale). Do this first to prove the bridge plumbing end-to-end cheaply.
2. **glibc-2.42 = the load-bearing net-new hop.** Build it with the R11 gcc-10.5.0 (musl-linked, but
   targeting via the sysroot wrapper) + R10 binutils-2.41 + the from-source linux-headers. This produces the
   first seed-rooted **glibc** sysroot. Nothing in the spine has ever built glibc — this is the single
   highest-risk, highest-value step and it must precede re-rooting binutils/gmp/mpfr/mpc (those must be built
   against the glibc ABI to match production, not against musl).
3. Then re-root gmp/mpfr/mpc and binutils against the from-source glibc (the spine already builds these
   from source at older versions — R8/R10 — so they are recipe-shaped; the work is the version bump to
   production 6.3.0/4.2.2/1.4.0 + 2.46.0 and the glibc-sysroot swap).

**Mechanism to change (the swap point for both B4 and B7):** today the builder `extract_to_root`s the 7
prebuilt tarballs into `/usr` of the sandbox (`main.go` `ExtractToRoot`, wired because cc1's hard-coded
`/usr/lib/gcc/<triple>/<ver>/cc1` paths must sit at `/usr`). B4 produces from-source replacements for those
tarballs; B7 flips the inputs from prebuilt-blob to from-source-sealed and deletes the `bootstrap_deps`
entries. The `extract_to_root` input is the single, well-understood cutover seam.

## (c) READY now vs the GAP

**Ready now:**
- The full attestation machinery the bridge rides on is proven: `CHAIN_ENFORCE` predecessor-closure walk,
  dual-sign (ECDSA P-256 + ML-DSA-65), byte-identical reproduction gates, seal-verify — all exercised
  through R8, including fail-shut on unattested predecessors.
- R6/R7/R8 sealed and seed-rooted: from-source gcc-4.0.4, musl-1.2.5, and gmp/mpfr/mpc already exist.
- The reusable bridge tooling is battle-tested: the `gcc-cc` sysroot wrapper (headers + `-B`/`-L` + `-static`),
  the single-writer musl-bedrock sysroot that defeats the `/usr` coin-flip, the per-rung mechanical checklist,
  and the `--disable-lto` / autotools-library-staging-prefix / no-`+`-in-version reflexes.
- Production toolchain recipes already build **from source** (gcc-15.2.0, glibc-2.42, …) — they're merely
  bootstrapped *by* the prebuilt blobs. So B5's "unchanged source, only the compiler changes" premise holds.
- RemoteCache carries the closure (first compile is the cost; wall-clears are ~14s), keeping B5/B7's
  whole-catalogue re-attestation tractable.

**The gap (what stands between now and B4):**
- R9 must seal; R10 (binutils-2.41) and R11 (gcc-10.5.0) must be *authored and sealed* — they don't exist yet.
- glibc-from-source has never been attempted anywhere in the spine (musl-only to date).
- No B2 determinism-pinning across the 7, and no DDC-capable second/diverse builder (B6) — the a/b
  bit-identical gate has no hardware. Current posture is single-builder, "breadth before repro."

## (d) Key risks in B4–B7

1. **musl→glibc pivot (B4, the net-new hop) — biggest risk.** The whole spine is musl; gcc-10.5.0 must
   compile modern glibc-2.42, and glibc-vs-musl in one sandbox is exactly the documented ~50/50 first-writer
   `/usr` pollution coin-flip. **Verify gcc-10.5.0 clears glibc-2.42's minimum-compiler bar** — recent glibc
   has been raising its required-GCC floor; if 2.42 needs newer than 10.5, B4 needs an extra gcc rung (a
   hidden R12) or B5's gcc-15 must be produced *before* the glibc re-root. Do not assume; probe it.
2. **B5 version jump: gcc-10.5.0 → gcc-15.2.0 in one hop.** A 5-major jump against from-source glibc is
   untested; GCC normally bootstraps from same/adjacent versions. gcc-15's host-C++ requirement vs gcc-10.5's
   C++17 is *probably* fine but must be confirmed; an intermediate gcc (e.g. 13.x) may be needed.
3. **B5 fixed point is NOT byte-identical to today's prebuilt (by design).** Different compiler → different
   bytes. The proof is self-hosting (bedrock-built gcc-15 rebuilds itself to a fixed point), not byte-parity
   with the current prebuilt. Any repro/DDC gate must be written to accept this, or it will false-fail.
4. **DDC hardware (B6) is an infra/procurement dependency, not just code.** A true a/b bit-identical gate
   wants genuinely diverse silicon (ideally different microarch / TEE) in Confidential Space. Today: one
   builder in us-west1-c. This is capacity + a second CS SKU, on the critical path for the *trust* claim
   (not for the functional rebuild).
5. **B7 whole-catalogue cost.** 368 production packages. The "22 convenience pkgs cascade for free" once the
   toolchain re-roots, but re-attesting the full closure against a new floor is hours-to-days of CS compute;
   entirely dependent on the warm RemoteCache staying warm across the cutover.
6. **Kernel/linux-headers TCB stays trusted, not bootstrapped** — honest scope boundary (same one Helsing
   draws); linux-headers is only attested-as-bytes + re-rooted, never source-bootstrapped. Not a blocker,
   but the earned claim must not overstate it.

## Observations (beyond scope, flagged per instructions)

- **The task-referenced doc `bedrock-ladder-R4-R11-2026-06-25.md` does not exist.** The R4–R11 detail now
  lives in `bedrock-r8-r11-forward-map.md` + `bedrock-r7-gcc-cc-wrapper.md` + the B3 row of the north-star.
  Whoever wrote the task prompt is pointing at a stale filename — worth reconciling so the "detailed spec"
  reference doesn't rot.
- **The north-star B3 row and the forward-map header lag reality.** The north-star's B3 cell still reads
  "R7–R11 remain" and the forward-map header says "R7 in flight," yet R7 and R8 are sealed and R9 is building.
  Living docs; a one-line status bump would keep the go/no-go legible to the next reader.
- **B4 is where the two halves of the bootstrap finally meet an ABI mismatch.** Everything sealed so far is
  musl; production is glibc. It's worth deciding *now*, before R11 seals, whether the target is truly
  "rebuild production glibc-2.42" or whether a musl-based production stdenv is on the table — that decision
  reshapes B4's entire risk surface (see risk #1). This is the single most consequential un-made decision.
  *(UPDATE 2026-07-03: DECIDED — target is glibc, the conventional musl→glibc path; musl-as-target was
  REJECTED (a 368-pkg musl port = no rebuild confidence). No longer an open question.)*
- **The `stage0.answers` file in R9** suggests some rungs now carry a curated Q&A/decision log alongside the
  recipe — a good pattern; consider standardizing it across rungs for auditability.
</content>
</invoke>
