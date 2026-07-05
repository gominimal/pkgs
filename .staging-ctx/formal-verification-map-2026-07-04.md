# FORMAL VERIFICATION OPPORTUNITY MAP — 2026-07-04

Synthesis of three research sweeps (in-repo invariant extraction; DDC/supply-chain prior art;
verified-toolchains/Lean landscape) into a tiered plan. Context: the gcc-15.2.0-glibc FIXED POINT
landed 2026-07-04; B6 (differential coreutils) and B7 (flip 7 trust-config leaves, ~368 pkgs
re-attest seed-rooted) are next. The four recent trust bugs — ALIASING, SELF-REF, OVER-COLLECTION,
TWINNING — were all violations of *statable* invariants found ad hoc at high cost. This map turns
those invariants into machine-checked artifacts, ordered by cost/value.

Tooling stance: **Lean 4 as the default vehicle** (operator taste, and it composes with the T2
self-referential story: our own proofs eventually checked by a seed-rooted checker). TLA+/Alloy
noted only where exhaustive small-scope search is strictly cheaper (concurrency interleavings,
quotient-graph counterexamples); even those can be done as Lean `decide`-style finite enumerations
if we want a single toolchain.

Repo layout proposal: `minimermetic/formal/` — a Lake project, one file per invariant, each file
header cross-linking the Go/Rust code site + the test that binds model to code. Specs are
**SPECS-with-proofs living in-repo**: the doc comment IS the deployed function's contract, CI runs
`lake build`.

---

## The four bugs as formal objects (the map key)

| # | Bug | Violated invariant, stated precisely | Verified-artifact tier |
|---|-----|--------------------------------------|------------------------|
| 1 | ALIASING | Slot state must be an order-independent function of the envelope SET; and (the deeper form) walkDeps traverses the **artifact-sha quotient** of the spec graph, and quotients of DAGs are not DAGs — aliased slots must be *terminal* | T0 (semilattice) + T1 (quotient acyclicity — the property that actually broke) |
| 2 | SELF-REF | No artifact in its own transitive resolvedDependencies (causality); walkDeps gray/black DFS + selfSHA skip | T0 (DFS contract) + T1 (state machine, incl. root-not-on-path and alias-blind-spot corners) |
| 3 | OVER-COLLECTION | Recorded provenance = acyclic ∧ faithful image of the planner's cycle-broken causal build | T0 (per-rung contract + global spec-DAG theorem) + T2 (planner-faithfulness, the hard half) |
| 4 | TWINNING | Provenance-label integrity: bytes may not flow between slots of different label class; every consumed non-self-built byte has a recorded origin | T0 (fill-if-empty monotonicity) + T1 (provenance completeness — **currently violated on warm cache**, see Dividends) |

---

## T0 — DO NOW (days): specs-with-proofs for the two deployed pure functions, plus the executable bridge

The two deployed fixes are small, effectively pure functions whose correctness is currently argued
in comments. Both admit short Lean proofs. The in-repo sweep already did the hard part: extracting
the *true* invariant (which differs from the comment in both cases).

### T0.1 — `mirrorSlotWinner` is a meet-semilattice fold (Lean 4)
- **Property.** `key(e) = (resolvedDepCount(e), payloadBytes(e))` lexicographic is a total order on
  valid envelopes (parseable, single subject == artSHA); `step(s,e) = min_key` is associative,
  commutative, idempotent; hence for any write order σ of a finite multiset W,
  `payload(fold(step, ⊥, σ)) = payload(min_key(W))`. **Convergence is on PAYLOAD, not envelope
  bytes** (equal-payload re-signs keep the first signature) — state this explicitly.
- **Artifact.** `formal/MirrorSlotWinner.lean`: envelope model, order totality, fold-permutation-
  invariance theorem, plus the two boundary lemmas (unparseable/wrong-subject parked = ⊥;
  malformed-buildDefinition parses as depCount-0 "leaf" — documented decision, not accident).
- **Code site.** `signer/main.go:864-897`; tests `signer/main_test.go:1104-1227`.
- **Bug caught.** #1 ALIASING (the deployed fix's core claim, now a theorem instead of a comment).
- **Model-code gap risk.** MEDIUM, and *productive*: writing the model forces three real gaps into
  the open — (a) the read-modify-write at `main.go:2288-2307` has **no GCS ifGenerationMatch**, so
  the theorem only holds for serialized writes (single-signer assumption, true today, silent);
  (b) the comment "a leaf ALWAYS outranks any chain-enforce rung" is **conditional, not
  structural** — `hermetic-builder-rs/src/main.rs:283-366` emits non-empty resolvedDependencies for
  non-CHAIN_ENFORCE pkgs whose hydrator tuples are covered, so a 10-declared-source leaf LOSES to a
  2-dep rung; only `depCount==0 ⇒ terminal walk` carries safety; (c) payload-canonicality is an
  assumption (builder-emitted JSON, not Go's marshal). Mitigation: T0.2.
- **Audience story.** "We replaced a race-prone last-writer-wins with a CRDT-style join, and here is
  the 60-line Lean proof that the slot is the meet of the envelope set" — instantly legible to both
  the formal-methods and distributed-systems crowds.

### T0.2 — N-writer permutation invariance as a Go property test (the tests≠proofs bridge)
- **Property.** Generate N∈[1,6] random valid envelopes for one artSHA (duplicate depCounts,
  malformed-buildDefinition members, wrong-subject members), fold the *deployed* Go function over
  every permutation, assert identical final payload = min_key of the valid subset.
- **Artifact.** `signer/main_test.go` property test (the existing 7 tests pin only 2-writer
  antisymmetry; associativity/fold-convergence is currently untested — the semilattice claim rests
  on inspection).
- **Bug caught.** #1; also immediately surfaces the malformed-leaf-holds-slot wrinkle
  (`resolvedDepCount`, main.go:794-801) and the untested rung-vs-rung ordering.
- **Model-code gap risk.** This IS the gap-closer: the Lean model proves the algebra, the property
  test proves the deployed Go implements that algebra. Ship them the same day, cross-referenced.
- **Audience story.** The honest "how we bind a proof to production Go without extraction" section
  of the writeup.

### T0.3 — `cycle_broken_deps_of` per-rung contract + global spec-DAG theorem (Lean 4)
- **Property.** (Local) `Ok(R)` ⇒ t∉R; every d∈R is either a non-cyclic closure member
  (¬reaches(d,t)) or a declared breaker of a cyclic one; deterministic pure function of (topology,
  replace_on_cycle); `Err(U)` ⇔ some cyclic peer lacks a breaker (fail-shut). (Global) Under axioms
  **A1** (envelopes record exactly this function) and **A2** (**breakers are terminal** — record(b)=∅),
  the union of all per-rung records is acyclic. Small induction: a recorded non-substituted edge
  r→d certifies ¬reaches(d,r); a cycle yields a reach/¬reach contradiction.
- **Artifact.** `formal/CycleBrokenDeps.lean` + a proptest in `crates/graph` (random digraphs +
  breaker maps) binding the model to the Rust.
- **Code site.** `crates/graph/src/graph.rs:245-280` (worktree `minimal-fetcher-env-vars`; vendored
  copy at `cache-publisher/vendor/minimal/crates/graph/src/graph.rs:245`).
- **Bug caught.** #3 OVER-COLLECTION (this function is its fix); the SELF-REF corollary (t∉R
  transitively) falls out.
- **Model-code gap risk.** MEDIUM-LOW for the local contract (the Rust is ~100 lines and readable);
  the value is that formalizing **forces A2 into the open** — nothing in the code checks breaker
  terminality ("pure prebuilt leaf" is build.ncl discipline, unenforced), and dedup() compares
  arena indices, not hashes. A1 (planner-faithfulness) is explicitly deferred to T2 — declare it as
  an axiom with a name, don't pretend it's proven.
- **Audience story.** "The provenance graph across 368 packages is a DAG *by theorem*, given two
  named axioms — and here's the CI check we added for the axiom the code didn't enforce."

### T0.4 — Cheap one-file lemmas and audits (fold into the same PR)
- **DSSE PAE injectivity** (~10-line Lean proof of length-prefix injectivity, citing
  PASETO/Soatok) + a grep/semgrep audit that no consumer re-parses the envelope after verification
  (DSSE protocol.md MUST). Code site: signer envelope construction/verification, orch verify.
- **Twin fill-if-empty monotonicity** (`breaker_hydrate.rs:156-186`): once a genuinely-built
  artifact occupies `spec_hash(S)`, twinning never displaces it; twinning idempotent. Partial
  answer to bug #4. State (don't prove) the converse hazard: twin-first masks the from-source build
  until eviction — B7's flip has an *operational* precondition (evict/never-twin the 7 slots).
- **spec_hash non-injectivity witness**: construct the two-recipe collision (cmds `["ab","c"]` ≡
  `["a","bc"]`, `spec_hasher.rs:220-267`) as a failing-by-design test + issue. The desired theorem
  "spec_hash collision ⇒ blake3 collision" is currently FALSE; record the mitigating axiom
  (recipes only from the cosign-signed vendored repo) until framing is fixed.

### T0 counterexample dividends (file as issues immediately — the sweep already found these)
1. **Missing `ifGenerationMatch`** on the mirror-slot read-modify-write (main.go:2288) —
  convergence theorem's serialization precondition; fix = CAS loop on object generation (T1.3).
2. **Warm-cache resolved_deps omission** (`breaker_hydrate.rs:120-123`): Pass 1's early-continue
  skips the ResolvedDependency push, so Pass-2 twinned bytes can be consumed with NO origin in that
  run's attestation. Concrete hole in B7's provenance-completeness. Fix: push on cache-hit too.
3. **Leaf-with-deps loses the slot** to a low-fanout rung (finding above) — either make the builder
  emit `[]` for all non-CHAIN_ENFORCE production builds, or restate the slot invariant.
4. **Pass-3 binds bootstrap artifacts by NAME, not spec_hash** (`breaker_hydrate.rs:188-285`) — a
  version bump changes spec_hash but the stale pinned tarball still fills the new slot; the weak
  link in B7's leaf flip. Typo'd pkg names are a silent no-op.

**T0 total effort: ~3-5 days.** Everything is a pure function + a property test; no new
infrastructure.

---

## T1 — WEEKS: DDC-formalize B6; model the composed system (walkDeps + leaf-owns-slot) end-to-end

### T1.1 — B6 as a Diverse Double-Compiling instance (Wheeler, replayed with our constants)
- **Property.** Wheeler's dissertation (arXiv:1004.5534) ships three prover9-generated FOL proofs,
  each independently re-verified with the ivy proof checker; mace4's role is different — it shows
  each proof's assumption SET is satisfiable (consistent), not that the proofs are valid. Sources
  published (Tables 2-4 + Appendix C). Proof #1 uses 5 assumptions, Proof #2 uses 9 ("9 instead
  of 5", §5.7). Instantiation:
  cT = bedrock ladder (hex0-rooted), stage1 = from-source gcc-15.2.0-glibc, cP = prebuilt
  toolchain, sA = coreutils source, cA = prebuilt-built coreutils, stage2 = from-source-built
  coreutils, and e1=e2=eA=eArun = the hermetic CS sandbox — which collapses converttext/retarget to
  identity, a simplification lemma Wheeler didn't have. Then **Proof #1 gives: stage2 = cA ⇒
  exactly_correspond(cA, sA, lsA, eArun)** — the coreutils binary corresponds to coreutils source
  *even if the prebuilt toolchain is malicious*. Contrapositive of Proof #2: a byte mismatch proves
  some assumption false (tamper OR nondeterminism OR recipe skew) — it does NOT say which; Wheeler's
  own first tcc DDC attempt mismatched and took "much effort" to track to TWO simultaneous benign
  causes (§7.1.3-7.1.4): a sign-extension miscompile (falsified cGP_compiles_sP) AND uninitialized
  junk bytes in 12-byte long-double constants — the latter env-dependent nondeterminism, exactly our
  lottery class.
- **Artifact.** Three pieces: (a) the replayed proofs — prover9 verbatim, or (per operator taste) a
  Lean 4 port of the 5-assumption/9-assumption models, `formal/DDC.lean`; (b) a **recipe-identity
  checker**: mechanical diff of the two in-toto envelopes asserting resolvedDependencies are equal
  *except* the toolchain entries (this is `definition_cA` made executable — any skew voids the
  theorem); (c) determinism gates (double-build) on both sides — discharges
  `sP_portable_and_deterministic`. `cT_compiles_sP` is stated openly as the hex0-audit residue:
  the formal chain bottoms out in the 229-byte seed's hand-auditability, which is the whole point.
- **Bug caught.** Not one of the 4 directly — B6 targets the *trusting-trust* class above them; but
  the recipe-identity checker mechanically prevents the "argued-equivalent builds that quietly
  differ" failure mode that produced the s4/R4-musl episodes.
- **Model-code gap risk.** LOW for the proofs (they're literally replayable); the risk lives in
  assumption discharge — mismatch attribution (tamper vs lottery vs nondeterminism) is the known
  weak spot. Adopt arXiv:2410.08427's **binary-equivalence-level lattice** as the principled
  fallback comparator when byte-compare fails benignly (instead of ad-hoc "demote the seal"
  decisions like the s4 float-gate).
- **Audience story.** The headline. "B6 is not *like* DDC, it *is* DDC — same theorems, machine-
  checked in 2007, instantiated against a 229-byte seed and SLSA-L4 attestations in 2026."
  Wheeler §8.7 (break the loop with an alternative trusted compiler) is literal prior art for
  `replace_on_cycle`; §8.8 (whole-system cA) is prior art for B7-scale. Bonus experiment: stage1 vs
  cP byte-compare (DDC one level up) — if it matches, `cP_corresponds_to_sP` is discharged
  retroactively for all 368 existing attestations.

### T1.2 — The composed system property: artifact-quotient acyclicity (Lean 4 state machine)
- **Property.** THE invariant the ALIASING outage actually violated, statable only about both fixes
  *together*: φ: Spec → SHA256 is not injective; walkDeps traverses G/φ; DAG(G_records) does NOT
  imply DAG(G_records/φ). Theorem: if every slot holds min_key of its envelope set (T0.1) AND every
  aliased sha (|φ⁻¹(s)|>1) has at least one depCount-0 writer, then every walkDeps traversal from a
  production consumer terminates without visiting any depCount>0 envelope at an aliased sha —
  quotient cycles unreachable. **Known counterexample class to keep in the model: two CHAIN_ENFORCE
  rungs aliasing one sha with no leaf writer** — the current system gives no guarantee; the
  depth-cap is the only backstop. This hole is live (linux_headers ≡ stage0-linux-headers, sha
  083cdb, was exactly this shape).
- **Artifact.** `formal/QuotientWalk.lean`: small-scope state machine (envelope store, writer
  events, walkDeps as a function) + the theorem + the counterexample as a `#eval`/decide-refuted
  non-theorem. Model walkDeps faithfully: gray/black DFS, allowlist-before-cycle-check ordering,
  **root-not-on-path asymmetry** (the root's subject is never pushed to onPath; the selfSHA comment
  is inaccurate for the root), **multi-subject disarms selfSHA** (len(Subject)==1 guard), and the
  alias-blind-spot of selfSHA (skips any byte-identical artifact, information-free but worth
  stating). Termination via depth cap + finite deps.
- **Code site.** `signer/main.go:609-753` (walkDeps) + :864 (winner) + `graph.rs:245` — joint.
- **Bug caught.** #1 (deep form) + #2 (walkDeps corners). This is where a mechanized model earns
  its keep: the property is currently *emergent* from two independently-argued components in two
  languages, and it is the one most likely to break again (next rung-rung alias).
- **Model-code gap risk.** HIGH-ish — this models a Go function + a Rust function + GCS semantics.
  Mitigations: keep the store model tiny (GCS single-object strong read-after-write, stated as an
  axiom); bind with an integration-style Go test replaying the historical aliasing scenario
  (poisoned-slot-then-reclaim end-to-end — currently untested; TestMirrorSlotWinner #7 only checks
  a leaf statement is a walk no-op).
- **Audience story.** "Content-addressing quotients your dependency graph, and quotients of DAGs
  are not DAGs" is a genuinely novel, crisply publishable observation for the reproducible-builds/
  in-toto crowd — nobody has formalized in-toto/SLSA verification semantics at all (confirmed gap;
  closest mechanized prior art is the Uptane Tamarin/Kind2 line).

### T1.3 — Convergence under concurrency: specify the CAS fix, prove it closes the interleaving
- **Property.** With ≥2 concurrent read-modify-write actors and no generation precondition, there
  is an interleaving leaving the rung parked (leaf-read, rung-read, leaf-write, rung-write) — prove
  the *negative* first; then prove wrapping the write in a CAS loop on object generation restores
  fold-convergence for every interleaving. 2-3 actors, tiny state space — the one place TLA+/
  PlusCal or a Lean finite enumeration are equally cheap; prefer Lean for toolchain unity.
- **Artifact.** `formal/SlotConcurrency.lean` + the actual `ifGenerationMatch` patch in
  `signer/main.go:2288-2303`.
- **Bug caught.** #1 recurrence under the future second signer / concurrent tasks. Today's safety
  is an undocumented single-signer deployment assumption.
- **Model-code gap risk.** LOW — the model is 4 lines of protocol; the risk is GCS semantics, which
  are documented (generation preconditions are the supported CAS primitive).
- **Audience story.** "We found the missing compare-and-swap by trying to prove the theorem" — the
  classic formal-methods payoff narrative, and it's true.

### T1.4 — Provenance completeness for breaker_hydrate (fix + property, bug #4 closed properly)
- **Property.** For every cache slot written/consumed via hydration in a run: if bytes(slot) were
  not produced by executing S's own spec, then ∃(u,h) ∈ resolved_deps of THIS run with
  sha256(fetch(u))=h and extract=bytes(slot). Currently violated (warm-cache hole, Dividend #2).
  Companion property: hydration-trigger-set = record-substitution-set (Pass 2 triggers on "declares
  replace_on_cycle"; the record substitutes only on "declares breaker AND reaches(top)" — a
  breaker-declaring non-cyclic S gets twinned bytes recorded as from-source: residual label-
  integrity mismatch). Formalize the label lattice: label(f.target)=label(f.source) for every fill;
  no downgrade-by-copy.
- **Artifact.** Fix in `breaker_hydrate.rs` (push ResolvedDependency on cache-hit; align Pass-2
  trigger with the record criterion or record the mismatch) + `formal/LabelIntegrity.lean` (small
  type-preservation lemma over the enumerated store-mutating ops — **the enumeration itself is the
  audit**) + Rust proptest.
- **Bug caught.** #4 TWINNING, fully this time (T0.4's monotonicity lemma was the easy half).
- **Model-code gap risk.** LOW-MEDIUM; the op enumeration must be complete (Pass 1/2/3 + genuine
  build + eviction), which is exactly the audit we want forced.
- **Audience story.** "Every non-self-built byte in the sandbox has a signed origin in the same
  run's attestation" — the B7 flip's integrity story, stated as an invariant instead of a hope.

**T1 total effort: ~3-6 weeks.** T1.1 and T1.3 are near-independent; T1.2 builds on T0.1/T0.3.

---

## T2 — MONTHS: lean4 as a seed-rooted rung → the attested proof checker checks OUR proofs

### T2.1 — Seed-rooted lean4 + lean4checker/lean4lean
- **Property/artifact.** Not a theorem — a *trust composition*: check the Lean proofs from T0/T1
  with a checker whose binary carries attested, TEE-measured, SLSA-L4 provenance chaining to the
  229-byte seed. Path: (1) `packages/lean` is mature and ~1 fix from landing (4.28.0; cadical/
  libuv/mimalloc pre-staged; /proc/self/exe PID-ns fix committed 6bbf4d2, rides next image
  rebuild + enqueue — **this is an image-rebuild away, not research**); (2) rebuild it from the
  from-source gcc-15-glibc fixed point (exactly a B7 leaf flip, no recipe change expected);
  (3) package `lean4checker` (wraps the trusted C++ kernel) and then `lean4lean` (Carneiro's pure-
  Lean kernel, partially verified, checks all of mathlib) as follow-on packages; (4) CI job:
  seed-rooted checker replays `formal/` .olean files.
- **Honesty caveat (state it, don't bury it).** Lean's stage0 is ~12 MLOC of compiler-GENERATED C
  committed to the repo (measured 2026-07-04: 11.79M lines of .c under stage0/ at master) —
  diffable but humanly unauditable. "Seed-rooted lean4" is
  honest only as "seed-rooted modulo the stage0 generated-C snapshot"; the external-checker route
  (small kernel, independently rebuilt) is what restores the de Bruijn criterion. Also:
  lean4checker/lean4lean cannot check native-evaluation proofs — keep `formal/` decide/kernel-only.
- **Bug-class caught.** None directly; this hardens the *meta* level — the proofs of the invariants
  that caught bugs 1-4 no longer depend on an unattested elan-downloaded binary.
- **Model-code gap risk.** N/A at the proof layer; the risk is build-engineering (known quantity).
- **Audience story.** The novelty claim, stated precisely (the prior-art sweep forces this
  narrowing): NOT "seed-rooted proof checker" — Guix has had a hex0-rooted (357-byte seed) package
  graph including Coq since April 2023 (its own stated caveats: a ~25 MiB binary Guile as build
  driver, kernel trusted). The unclaimed composition is **a proof-checker binary whose entire causal build history is
  cryptographically attested and third-party verifiable WITHOUT re-execution** (Guix's trust model
  is rebuild-it-yourself-or-trust-substitutes; no per-step signed provenance, no TEE measurement).
  Closest cousins to cite-and-differentiate: Guix full-source bootstrap, StageX, Project Oak/CFC
  (TEE provenance, no seed), Milawa/Jitawa + Candle (proof axis only), Kettle (arXiv:2605.08363,
  TEE-attested builds, no seed, no provers). Maximal flourish: the checker checking the proofs *of
  the invariants of the pipeline that built the checker*.

### T2.2 — Planner-faithfulness (the A1 axiom discharged)
- **Property.** The set of cache slots the planner actually mounts for a CHAIN_ENFORCE build of t
  corresponds 1:1 to `cycle_broken_deps_of(t)` — substitution happens under exactly reaches(D,t) ∧
  breaker-declared, no more, no less. Currently asserted only in comments ("honored only by the
  planner", graph.rs:218). This is the faithful-subset half of bug #3; a planner-side divergence
  would be its unchecked dual.
- **Artifact.** Either a Lean model of `crates/graph/src/planner.rs` against
  `cycle_broken_deps_of`, or (pragmatic first step) a **runtime cross-check**: builder asserts at
  mount time that mounted-slot set == recorded set, fail-shut. Do the runtime check in T1
  timeframe; the proof is the T2 item.
- **Bug caught.** #3's other half. Largest-scope property here — two components, no shared oracle.
- **Model-code gap risk.** HIGH (planner is the biggest code surface in the map) — hence runtime
  cross-check first, proof second.
- **Audience story.** "Recorded provenance is a *theorem about* the build, not a report from it."

### T2.3 — spec_hash injectivity repair + proof
- Fix the framing (length-prefix cmds/name/args/AttrValue), then prove σ injective ⇒ collision
  requires blake3 collision. Keyed by the T0.4 witness. Medium; batch with a planned graph-crate
  change since it invalidates all existing spec_hashes (cache migration — schedule deliberately).

**T2 total effort: ~2-4 months, mostly build/infra engineering, parallelizable with B7.**

---

## T3 — MOONSHOT: verified-compiler-class rungs and the whole-pipeline adversary model

### T3.1 — CakeML/Candle rung (do this BEFORE dreaming about CompCert)
- **Property/artifact.** CakeML releases ship `cake.S` — verified x86-64 assembly *generated
  in-logic* (the compiler bootstrapped inside HOL4; POPL'14, backend detailed in JFP'19), needing
  only our seed-rooted binutils/gcc + a ~500-line UNVERIFIED C FFI wrapper (`basis_ffi.c`, 485
  lines at master — it, the C compiler on it, and the linker are the stated TCB) to assemble. A `cakeml` package is the cheapest possible
  "binary with a machine-checked end-to-end correctness theorem AND attested seed-rooted
  provenance." Candle (verified HOL Light kernel on CakeML) is the flagship prover variant.
  Re-running the in-logic bootstrap (HOL4 + PolyML; hours-scale, CakeML docs suggest ~64 GB RAM
  minimum) is a later, heavier rung.
- **CompCert verdict: inspiration-only.** Non-commercial license; Coq+OCaml closure (OCaml itself
  bootstraps from a committed bytecode blob — its own trusting-trust hole); CompCert C is a subset
  that can't build glibc/kernel-grade code, so it cannot replace a gcc rung. At most a differential-
  testing leaf. The reusable *idea* from that world is seL4's graph-refine: per-build translation
  validation of the unverified compiler's output — exactly the ladder's adversary model, if a
  "validate a rung's compilation" milestone ever appears. MM0 (Metamath Zero) is the active project
  to track: if its x86-64 self-verification completes, an MM0 binary in the ladder is the strongest
  composition available.
- **Bug-class caught.** None of the four — this tier targets compiler-defect and trusting-trust
  classes below them (the tcc-mes >=4-arg miscompile and the R4-musl corruption live here: a
  verified rung turns "lottery" into "theorem violation").
- **Audience story.** Milawa's each-rung-certifies-the-next ladder is the right vocabulary for the
  bedrock north-star doc; CakeML-in-the-ladder is the first time the proof axis and the provenance
  axis meet in one binary.

### T3.2 — Whole-pipeline mechanized adversary model (Uptane-style)
- Model builder-attest → signer verify_token → mirrorSlotWinner → cache-publisher → consumer
  verify as an LTS with a Dolev-Yao-ish adversary (controls arrival order, replays envelopes, owns
  every non-TEE component); prove all four invariants in all reachable states. Template: Lorch,
  Larraz, Tinelli & Chowdhury, RAID 2024 — eager Kind2+Tamarin combination, the most comprehensive
  published mechanized analysis of a signed-metadata supply-chain framework (found 6 new vulns;
  prior Uptane/OTA analyses existed but hit state-space explosion / termination walls). **No such analysis exists for in-toto/SLSA — confirmed gap,
  publishable.** Multi-month; T1.2/T1.3 are its seedlings and de-risk it.

### T3.3 — End-to-end seed-rooted attestation theorem
- Single statement: for every published artifact there exists a finite DAG of DSSE envelopes,
  KMS-verified, edges = resolvedDependencies, leaves = exactly {hex0 seed, sha-pinned sources},
  internal consistency by the T0/T1 lemmas. Checkable BY the T2 seed-rooted checker for maximal
  self-reference. This is the paper's closing theorem.

---

## Cross-cutting: the axiom ledger

Every Lean file declares its assumptions from the sweep's inventory, by name, so the informal
arguments can't quietly assume more than the code enforces. Load-bearing ones: (1) single
serialized signer [until T1.3]; (2) sha256 collision resistance [identity relation — also the
*source* of the aliasing quotient]; (3) sole-writer IAM on the mirror bucket [what makes
mirrorSlotWinner not a trust boundary]; (4) depCount-0 ⇔ production leaf [conditional — Dividend
#3]; (5) breaker terminality [A2, unenforced — add CI check]; (6) planner faithfulness [A1, T2.2];
(7) GCS single-object strong consistency; (8) payload canonicality; (9) trust-config curation;
(10) single-subject statements [selfSHA disarms otherwise]; (11) spec-serialization injectivity
[FALSE today — T0.4 witness]; (12) Pass-2 trigger = record criterion [mismatched — T1.4].

## Model-code gap: the standing mitigation

Lean models don't run in production. The discipline throughout: every proved property ships with a
property-based test executing the REAL Go/Rust against the model's statement (T0.2 pattern), and
every axiom either gets a CI check (A2, recipe-identity) or a named entry in the ledger. Where the
gap is structural (two languages computing "the same" invariant — cycle_broken_deps_of vs
walkDeps), state the two-implementation agreement as its own theorem-shaped test.

---

## RECOMMENDATION — first move

**Do T0.1 + T0.2 together, this week, as one PR: the Lean 4 semilattice proof of
`mirrorSlotWinner` paired with the N-writer permutation property test against the deployed Go —
and file the four counterexample dividends as issues the same day.**

Why this exact move:
- ALIASING was the most expensive bug and this is its fix's actual correctness argument, currently
  resting on 2-writer tests and a comment that is (provably) overstated.
- It is the smallest artifact that exercises the full intended workflow — in-repo Lean spec, proof,
  executable bridge to production code, axiom ledger — so it sets the template every later tier
  reuses.
- The modeling *already paid for itself in the research phase*: it surfaced the missing
  ifGenerationMatch, the leaf-with-deps ranking hole, and the malformed-leaf wrinkle. Landing the
  proof + issues together makes the "we found real bugs by stating the theorem" story concrete on
  day one — the exact narrative arc the public writeup needs.
- It requires zero new infrastructure and doesn't block or touch B6/B7; T0.3 (cycle_broken_deps_of)
  follows immediately after as the second file in `formal/`, and T1.1 (B6-as-DDC) can start in
  parallel since B6 is next on the ladder anyway — its recipe-identity checker should exist BEFORE
  the first differential build runs, so B6's byte-compare inherits Wheeler's theorem from run one.
