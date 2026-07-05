# PROVER-HOLES DEPLOY PACKET — 2026-07-04

Consolidates the Track A/B/C fixes produced by the formal round (the Lean counterexamples in
`minimermetic/formal/` → code fixes → re-proofs, README "REPROVED post-fix") into ONE deploy story
riding the ALREADY-PLANNED B7-window image rebuilds. Companions:

- `minimermetic/formal/README.md` — findings ledger (F1–F8 numbering source), axiom ledger, model↔code map
- `.staging-ctx/b4-reattest-packet-2026-07-04.md` — the B7-window re-seal order this packet slots into
- `.staging-ctx/b7-flip-plan-2026-07-03.md` — flip diffs + runbook (steps 2/5 are the rebuild moments)
- `.staging-ctx/formal-verification-map-2026-07-04.md` — the opportunity map that named the dividends

F-numbering (as carried in code comments): **F4** = mirror-slot CAS (`signer/main.go:1011`),
**F6** = warm-cache/twin provenance recording (`breaker_hydrate.rs:62`), **F7** = breaker-aliases-toplevel
gate (`graph.rs:319-323`), **F8** = breaker-on-own-cycle gate (`graph.rs:324-331`), **F9** = Pass-3
name-binding fail-loud gate (`breaker_hydrate.rs:81, 406`).

---

## 0. TL;DR

Three change surfaces, two image rebuilds, ZERO extra image cycles: everything rides the rebuilds
the B7 window already schedules (b4-reattest packet §2 Step 0 and flip-plan runbook step 5).
**F6 hard-gates the flip** (provenance completeness for the 368-pkg cascade) and **must be live
before the B4→B5 re-seal starts**, not just before the flip. F9 and F7 gate as fail-shut guardrails
for exactly the edit class the flip performs. F8, F4-CAS, and the signer ranking hardening are
hardening that could trail — but they ship in the same images anyway, so nothing actually trails
except the formal CI wiring and the dividend issues.

One non-obvious re-attest wrinkle (§4): an F6-grown envelope re-signed at an UNCHANGED artifact sha
LOSES slot arbitration to its own smaller-depCount v1 envelope (fewest-deps-wins) — the
classifier-gated `.intoto` delete in b4-reattest §2 Step 2/3 is therefore REQUIRED, not just
lineage hygiene.

---

## 1. WHAT CHANGED — the three surfaces

### Track A — minimal-crates (`crates/graph`, worktree `minimal-fetcher-env-vars`, uncommitted)
`crates/graph/src/graph.rs` (+220 lines incl. tests) + `lib.rs` export:

- **F7 gate** (`graph.rs:319-323`): `cycle_broken_deps_of` now FAILS SHUT
  (`CycleBreakError::BreakerAliasesToplevel`) when a cyclic peer's `replace_on_cycle` breaker IS the
  toplevel — the SELF-REF bug reintroduced through the breaker channel. Formal: axiom **A1
  discharged** (`toplevel_not_recorded_enforced`, hypothesis-free).
- **F8 gate** (`graph.rs:324-331`): fails shut (`CycleBreakError::BreakerOnCycle`) when a breaker
  itself sits on a dependency cycle (breaker-terminality, axiom A2's per-record half). Formal: A2
  **narrowed to `BreakersCycleFree`, NOT discharged** — see finding 8 in §6.
- New error variants + tests pinning the exact Lean witnesses (`gBreakerAliasesTop`, `gSelfBreaker`).

Deploy vehicle: **vendored into the builder image** (`hermetic-builder-rs/Cargo.toml` →
`vendor/minimal/crates/graph`). No standalone deploy exists; requires `MINIMAL_SRC` pointed at the
worktree during the image build (standing PKGS_SRC/MINIMAL_SRC footgun — set explicitly).

### Track B — signer (`minimermetic/signer/`, uncommitted, +300 main.go / +625 main_test.go)
- **Rule 0** (`main.go:926-929`): wrong-subject incoming refused before anything else (was: could
  perturb arbitration). Kills historical finding 1 (order-independence needed all-valid writes).
- **Malformed-bottom tier** (`main.go:940-949`): a malformed-buildDefinition envelope ranks BELOW
  every well-formed one instead of parsing as a perfect depCount-0 leaf (historical finding 3);
  corrupt parked slots can no longer launder an eviction (finding 2,
  `TestMirrorSlot_CorruptCannotLaunderEviction`).
- **F4 CAS** (`publishMirrorSlot`, `main.go:1008-1045` + `gcsMirrorSlot.WriteIf` with
  `GenerationMatch`): the mirror-slot read-modify-write is now a compare-and-swap loop on GCS object
  generation, fail-shut after N conflicts. Removes the undocumented single-signer serialization
  assumption from the safety argument.
- Result: the Lean order-independence/leaf-dominance theorems now hold **unconditionally** over
  arbitrary write multisets (`slotFold_order_independent`, `leaf_dominance` — no hypotheses).

Deploy vehicle: **signer image rebuild + cosign + Pulumi digest bump + VM bounce.**

### Track C — builder (`minimermetic/hermetic-builder-rs/`, uncommitted, +468 breaker_hydrate.rs / +53 main.rs)
- **F6 warm-cache/twin provenance recording** (`breaker_hydrate.rs` passes 1/2/3): every (uri,
  sha256) tuple whose bytes a build CONSUMES is pushed to `resolved_deps` whether fetched by this
  run or already warm in the local cache. Before: pass 1's warm-hit early-continue and pass 3's
  "already in cache" skip recorded NOTHING → Pass-2-twinned bytes entered builds with no origin in
  that run's attestation (the B7 provenance-completeness hole, formal-map Dividend #2). Recorded set
  is now a function of the build closure, never cache temperature; `LazyStorage` makes the warm path
  credential-free and unit-testable (~200 lines of F6 tests).
- **F9 name-binding fail-loud gate** (`unmatched_bootstrap_bindings`, checked at the top of
  `hydrate_closure`): any `bootstrap_artifacts.applies_to_packages` name matching NO spec anywhere
  in the graph is a hard `bail!` listing every offender (was: Pass-3 logged a skip and moved on —
  a typo silently disabled a trust anchor's hydration). Names outside THIS closure remain a
  legitimate non-fatal skip.
- **F7/F8 error surfacing** (`main.rs:1039-1062`): the new `CycleBreakError` variants from Track A
  mapped to operator-legible chain-probe refusals citing the Lean witnesses.

Deploy vehicle: **builder image rebuild** (same image build as Track A — one artifact).

### Formal — `minimermetic/formal/` (new, not yet committed)
`Formal/MirrorSlot.lean` (1040 lines) + `Formal/CycleBroken.lean` (989 lines), **0 sorries**, Lean
4.31.0 core-only, axiom-hygienic (`propext`/`Quot.sound`/`Classical.choice` at most; witnesses
axiom-free). **No deploy surface at all** — nothing runs in production. Wants: repo commit + a CI
`lake build` job. Pure trail.

---

## 2. DEPLOY SEQUENCING — ride the B7-window rebuilds, zero extra image cycles

The B7 window already schedules exactly the two rebuilds these tracks need:

| Track | Vehicle | Already-planned slot |
|---|---|---|
| A (graph crate) + C (builder) | builder image rebuild | b4-reattest packet §2 **Step 0** (`orch image-rebuild --target rust-builder` for the libc.so patch vendor); the flip's own rebuild at flip-plan runbook step 5 is a second, later builder rebuild — Tracks A+C must be in the FIRST one (see ordering below) |
| B (signer) | signer image rebuild + bounce | same Step-0 window: the signer must be bounced there anyway (`EXPECTED_BUILDER_IMAGE_DIGEST` refresh, orch does it since 0d8f3af). Fold the signer IMAGE rebuild into that bounce — one deploy action in a window that already touches the signer, no additional cycle |
| Formal | none (CI only) | any time; recommend same commit series for review coherence |

**Hard ordering requirement — all three tracks live BEFORE b4-reattest §2 Step 1, not merely
before the flip.** Reason: Steps 1–4 re-seal glibc-bedrock-2.42 → binutils-2.46-glibc →
gcc-15.2.0-glibc → gmp/mpfr/mpc-glibc, and those envelopes become the flip's trust anchors
(`<B4_*_SHA>`/`<B5_GCC_SHA>`). If F6 is not live when they re-seal, the anchors themselves carry
the warm-cache under-recording and would need a THIRD re-seal round to be complete. Deploying
Tracks A+B+C at Step 0 makes the re-seal cascade produce F6-complete envelopes on the first pass.

Concrete Step-0 amendment (supersedes the b4-reattest Step 0 text, which covers only the patch):

1. Commit Track A in the `minimal-fetcher-env-vars` worktree; commit Tracks B+C + `formal/` in
   minimermetic; commit the parked libc.so patch in pkgs-hermetic-all (separate commits,
   one-architectural-increment each).
2. `orch image-rebuild` with `MINIMAL_SRC` = the worktree (Track A rides the vendor) and
   `PKGS_SRC` = pkgs-hermetic-all HEAD (libc.so patch rides the vendor). Verify builder digest
   CHANGED and builder RUNNING on it.
3. Rebuild + cosign + deploy the **signer** image (Track B); verify signer RUNNING on the new
   digest with fresh `EXPECTED_BUILDER_IMAGE_DIGEST`. (If `orch image-rebuild` doesn't cover the
   signer image target, this is the one manual step — still inside the same window, zero extra
   VM-bounce cycles beyond the bounce already required.)
4. Proceed to b4-reattest §2 Steps 1–4 unchanged.

The flip-plan runbook step-5 rebuild (trust-config vendor for the 7 relocations) then happens later
with Tracks A+C already inside the image — no interaction.

---

## 3. GATE vs TRAIL — which fixes block the B7 flip

### GATES the flip

- **F6 — CERTAIN GATE.** The flip's integrity story is "every non-self-built byte has a signed
  origin in the same run's attestation" over a 368-pkg cascade run **deliberately warm** (flip
  runbook step 7 keeps RemoteCache warm; readiness risk #5). Without F6, warm hydration is the
  COMMON case in the cascade and the resulting catalogue attestations systematically omit the
  twinned/warm origins — including, post-flip, the 7 from-source leaf tuples themselves. The
  post-flip audit (runbook step 8: "no consumer still resolves a prebuilts/... url") is only
  meaningful if consumers record their hydrated origins at all. Also gates the B4 re-seal (§2).
- **F9 — GATE (guardrail for the flip's exact edit class).** The flip relocates 7 entries into
  `bootstrap_artifacts` with stringly-typed `applies_to_packages` names — the footgun the flip plan
  itself flags (§5: "a typo silently populates the wrong slot (or no slot)"). Pre-F9 a typo is a
  silent no-op = "prebuilt bytes under a from-source label" (formal-map Dividend #4's first half).
  F9 turns it into a hard refusal at hydrate time. The flip should not be executed without it.
- **F7 — GATE (same rationale, breaker channel).** The flip edits all 7 `replace_on_cycle` arms in
  one window; F7 is the fail-shut against a mis-edit that points a peer's breaker back at the
  toplevel (SELF-REF reintroduced). Near-zero marginal cost — it's in the Track-A/C image the flip
  needs rebuilt anyway.

### Hardening — can trail in principle (but ships in the same images, so nothing waits)

- **F8** — post-flip breakers are dep-less Source-only specs (url+sha, no build_deps), which cannot
  sit on a cycle; F8 defends a future breaker-with-deps. Ship it, but it does not gate. NOTE the
  formal residual (finding 8, §6.4): F7+F8 together still do NOT give global acyclicity —
  `BreakersCycleFree` is enforced nowhere. Flip-time compensating check: eyeball that each of the 7
  new breaker specs remains a pure Source leaf (30 seconds, add to flip checklist).
- **F4 CAS** — today exactly one signer exists; the CAS closes a latent race for the future second
  signer / concurrent tasks. Correctness under the current deployment was already argued (serialized
  writes). Trail-safe; rides Track B regardless.
- **Rule 0 + malformed-bottom tier** — the laundering/malformed counterexamples require corrupt or
  wrong-subject envelopes in the slot, which under sole-writer IAM + single signer means our own
  bug, not an adversary. Hardening; but the flip cascade is the highest-slot-traffic period the
  system will ever see, so having unconditional leaf-dominance live during it is cheap insurance —
  and it rides Track B regardless.
- **Formal CI (`lake build` job) + `formal/` commit** — pure trail, zero runtime surface.
- **Dividend gh issues (§6)** — trail; file them whenever, none block.

---

## 4. RE-ATTEST IMPLICATIONS — who re-seals, and the depCount wrinkle

**Do any changes alter attestation BYTES for existing pkgs?**

- **F6: YES, for warm-run envelopes — this is the point.** For any pkg whose sealed envelope came
  from a warm-cache run that consumed hydrated prebuilt/bootstrap/twin bytes, a rebuild under F6
  emits MORE `resolvedDependencies` entries (the payload grows; a cold-run envelope is unchanged —
  F6 makes warm ≡ cold, it never changes what a cold run recorded). Subset invariant unaffected:
  the new entries are hydrator tuples, already inside `declaredSources ∪ bootstrap_deps ∪
  bootstrap_artifacts ∪ release-channel`.
- **F7/F8/F9: NO.** Fail-shut gates; on every build that succeeds, output is byte-identical.
- **Track B (signer): NO payload changes.** Ranking + CAS change which envelope OCCUPIES a
  contested slot and preserve first-written signature bytes on equal-payload re-signs (finding 7);
  they never alter any envelope's own bytes.
- **Track A: NO** for non-CHAIN_ENFORCE (unchanged path); for CHAIN_ENFORCE, only refusals changed.
- **Spec_hashes: UNCHANGED by all tracks** (no recipe bytes touched). The only spec_hash change in
  the window is the libc.so patch itself, already fully accounted in the b4-reattest packet.

**Which rungs re-seal?** No NEW re-seal set beyond what the B7 window already schedules:

1. **B4→B5 chain (glibc-bedrock-2.42, binutils-2.46-glibc, gcc-15.2.0-glibc, gmp/mpfr/mpc-glibc)**
   — already re-sealing per b4-reattest §2. With Tracks live at Step 0, these come out
   F6-complete for free. This matters because they are the flip's trust anchors.
2. **The ~368-pkg catalogue** — already re-attesting in the flip cascade (Caveat B); every one of
   those envelopes is emitted post-F6, so the whole catalogue exits the window complete.
3. **Bedrock spine below B4 (R1–R12, stage0-*)** — NOT re-sealed. Their existing envelopes may
   under-record warm-consumed hydrator bytes, but a MISSING resolvedDependencies entry never breaks
   a chain-enforce walk (absent edge = not traversed) — it is a completeness gap in historical
   envelopes, not a validity break. Optional lineage hygiene: classifier-gated delete + re-sign of
   DETERMINISTIC rungs only, per standing cascade rules. **NEVER stage0-linux-headers-6.12.43**
   (standing exclusion) and never the lottery rungs (stage0-tcc-0.9.27-musl-s4).

**The depCount-growth slot-arbitration wrinkle (load-bearing, new in this packet):**
`mirrorSlotWinner` ranks fewest-resolvedDeps first within the walkable tier. An F6-grown envelope
re-signed at an UNCHANGED artifact sha (the sha-idempotency fork in b4-reattest §2 Steps 2/3 —
plausible for the determinism-hardened B5 rungs) has MORE deps than its parked v1 envelope → the
v1 envelope WINS and the new, more complete envelope is REFUSED. Consequence: for any
same-sha re-sign intended to upgrade lineage/completeness, the classifier-gated
`.intoto` delete of the v1 slot is **REQUIRED for the F6-complete envelope to park at all** — it is
not merely audit hygiene. The b4-reattest packet already recommends the delete+re-sign branch;
this upgrades that recommendation to a requirement. (New-sha re-seals are unaffected — fresh slot.)

---

## 5. CHECKLIST

Pre-deploy (local, cheap):
- [ ] `formal/`: `lake build` clean, zero sorries; `#print axioms` spot-check on
      `slotFold_order_independent`, `provenance_acyclic_enforced`.
- [ ] Signer: `go test ./...` in `minimermetic/signer` (1900-line test file incl. the N-writer
      permutation oracle + CAS conflict tests) green.
- [ ] Builder + graph: `cargo test` in `hermetic-builder-rs` (F6 warm-path tests, F9 binding tests)
      and in the worktree's `crates/graph` (F7/F8 witness tests) green.
- [ ] Commit hygiene: Track A commit in `minimal-fetcher-env-vars`; Tracks B+C + `formal/` in
      minimermetic (separate commits); libc.so patch in pkgs-hermetic-all. No whole-crate fmt.
- [ ] `MINIMAL_SRC` explicitly = `~/workspace/worktrees/minimal-fetcher-env-vars`; `PKGS_SRC`
      explicitly = hermetic-all worktree (both silent-wrong-default footguns).
- [ ] **F9 dry-run against CURRENT trust-config**: F9 fails the build if any existing
      `applies_to_packages` name is stale — run the builder's graph-load path (or the F9 unit
      helper) over today's trust-config BEFORE deploying, so a latent stale entry doesn't wedge the
      Step-1 enqueue. If it fires, fix the entry first; that's F9 working.

Deploy (the Step-0 window, §2):
- [ ] Builder image rebuild (Tracks A+C + libc.so patch vendored); digest CHANGED; builder RUNNING
      on new digest.
- [ ] Signer image rebuild + cosign + deploy (Track B); signer RUNNING;
      `EXPECTED_BUILDER_IMAGE_DIGEST` fresh.
- [ ] Smoke: enqueue one cheap non-chain pkg — attestation byte-identical to pre-deploy (proves
      F6/F7/F8/F9 are inert on the cold, healthy path).
- [ ] Smoke: one warm-cache chain-enforce rebuild of an already-done pkg on the VM — its emitted
      resolvedDependencies now include the hydrator tuples (F6 visible), subset check passes.

Then (unchanged, other packets):
- [ ] b4-reattest §2 Steps 1–4 (serial, gated), taking the **delete+re-sign branch as REQUIRED**
      on any same-sha fork (§4 wrinkle).
- [ ] B6 differential; flip placeholder fill; flip runbook 1–9. Flip-time extra from this packet:
      verify the 7 new breaker specs are dep-less Source leaves (F8 residual, §3).

Trail (file/land any time, none block):
- [ ] CI job: `lake build` on `formal/` per PR.
- [ ] File the four dividend issues (§6).

---

## 6. DIVIDEND ISSUES — drafts for `gh issue create`

### 6.1 F4 residual: single-signer serialization was load-bearing and undocumented; CAS interleaving not mechanized
The mirror-slot read-modify-write (`signer/main.go`, pre-fix) had no GCS generation precondition;
the Lean order-independence theorem only covered serialized folds, so production safety silently
rested on "exactly one signer exists." FIXED in code (`publishMirrorSlot` CAS on object generation,
fail-shut after N conflicts). Residuals to track: (a) the linearization argument (generation
preconditions ⇒ every successful publish is atomic against its read state) is prose + Go tests,
not a mechanized model — formal-map T1.3 (`formal/SlotConcurrency.lean`) is the follow-up;
(b) an integration test against real GCS semantics (not the in-memory `mirrorSlot` fake) before any
second signer / concurrent-task deployment; (c) the deployment assumption should be retired from
the axiom ledger only when (a) lands. Labels: `signer`, `formal`, `hardening`.

### 6.2 F9 residual: Pass-3 still binds bootstrap_artifacts by NAME, not spec_hash
The F9 gate closes the typo/no-match silent no-op, but binding remains stringly-typed: a name that
RESOLVES can still be stale in meaning — a version bump changes the target's spec_hash while the
pinned tarball (old bytes) still fills the NEW slot (formal-map Dividend #4's second half; F9
cannot see this). Also: `applies_to_packages` names like `gcc` vs `gcc (prebuilt)` are load-bearing
and reviewer-invisible; and the two byte-identical trust-config copies can drift. Proposed fixes,
in order: (1) bind entries by (name, version) or directly by spec_hash with a build-time assert;
(2) builder assertion that a leaf's `replace_on_cycle` url equals its matching
`bootstrap_artifacts` url (the flip plan's matched-pair invariant); (3) single-source trust-config
with a build-time diff assert. Labels: `builder`, `trust-config`, `B7`.

### 6.3 spec_hash is non-injective: framing collision witness
`spec_hasher.rs:220-267` concatenates list fields without length-prefixing, so distinct recipes
collide: cmds `["ab","c"]` ≡ `["a","bc"]` (same digest input). The desired theorem "spec_hash
collision ⇒ blake3 collision" is FALSE today. Action: (1) land the failing-by-design witness test
in `crates/graph` (not yet written — grep confirms no witness in the file) documenting the
collision; (2) record the mitigating axiom (recipes come only from the cosign-signed vendored repo,
so no adversary chooses recipe bytes) in the axiom ledger; (3) fix = length-prefix framing for
cmds/name/args/AttrValue — NOTE this invalidates every existing spec_hash (full cache migration),
so schedule it deliberately with a planned graph-crate change, NOT inside the B7 window
(formal-map T2.3). Labels: `minimal-crates`, `formal`, `breaking-cache`.

### 6.4 Finding 8: F7+F8 do not give global acyclicity — `BreakersCycleFree` is enforced nowhere
Machine-checked residual (`finding_enforced_checks_insufficient`, `gBreakerWithDeps` in
`Formal/CycleBroken.lean`): a breaker that is off-cycle and non-aliasing (both gates pass, records
emit `Ok`) but has a dependency edge back into the cycle it breaks yields a genuine 2-cycle in the
union of emitted records. Unreachable in production while breakers are dep-less `-prebuilt`/Source
specs, and a violation fails shut at verify time (signer walk cycle detection) — availability, not
integrity. Mechanical fix if wanted: strengthen F8 to scan the breaker's CLOSURE for on-cycle
nodes (exactly `BreakersCycleFree`; the machinery already exists in `cycle_broken_deps_of`).
Interim: a CI/flip-time check that every `replace_on_cycle` target has zero deps. Labels:
`minimal-crates`, `formal`, `hardening`.

---

## Observations (beyond scope)

- **The b4-reattest packet's Step 2/3 "recommendation" needs upgrading to a requirement** in light
  of §4's depCount wrinkle: same-sha re-signs with F6-grown payloads are REFUSED by the fixed
  ranker unless the v1 `.intoto` is deleted first. Suggest annotating that packet when this one
  lands.
- **The F9 gate can fire on TODAY'S trust-config at first deploy** (any already-stale
  `applies_to_packages` entry becomes a hard error at the next builder start). The checklist's
  dry-run covers it, but whoever executes Step 0 should expect this failure mode and read it as
  the gate working, not a regression.
- **Signer image rebuild automation gap**: `orch image-rebuild` targets the rust-builder; the
  signer image path is less automated (memory: manual build + cosign + digest bump). If Track-B
  style signer changes recur, folding a `--target signer` into orch is the same class of win as
  the builder automation was.
- **Formal round ROI note for the writeup**: every one of F4/F6/F7/F8/F9 was found by attempting a
  proof, and all five fixes deploy inside image rebuilds that were already scheduled for other
  reasons — the "formal methods paid for themselves before the first CI job existed" narrative is
  concrete and dateable (2026-07-04).
