# Durable mirror spec-qualified fix — #14 D2 (leaf-owns-slot)

Date: 2026-07-03
Author: Claude (subagent), for bryan
Status: REVIEW-READY branches, NOT deployed. No gcloud writes, no image rebuild.

## TL;DR

Chose candidate **(b) leaf-owns-slot**, implemented as an order-independent,
content-derived precedence on the signer's mirror-envelope write. A CHAIN_ENFORCE
re-sign can no longer evict a production leaf from a shared content-addressed slot.
Back-compat: the ~386 already-signed `.intoto` at `sha256/<art>.intoto` are
untouched (no layout change, no mass re-sign). Composes with D1; does not touch the
walk (selfSHA guard + genuine-cycle detection unchanged).

## Branches / diffs

- `minimermetic` @ branch **bryan/durable-mirror-spec-qualify** (off
  bryan/orch-nickel-eval-bucket, commit fd26e6c):
  - `signer/main.go` — new helpers `resolvedDepCount`, `envelopePayloadBytes`,
    `mirrorSlotWinner`; wired a read-back precondition into `signerOnce`'s publish
    stage before the `sha256/<art>.intoto` write.
  - `signer/main_test.go` — 7 new `TestMirrorSlotWinner_*` tests (+ `bytes` import).
  - `hermetic-builder-rs/src/intoto.rs` — one cross-language contract test
    (`leaf_and_enforcing_shapes_are_distinguishable_by_dep_count`).
- worktree `minimal-fetcher-env-vars` @ branch **bryan/durable-mirror-spec-qualify**
  (off e3db4f1a, commit 21b4921d):
  - `crates/graph/src/graph.rs` — one test
    (`leaf_records_empty_closure_rung_records_nonempty`) pinning the graph-level
    source of the dep-count asymmetry the signer keys on.

## Why (b), not (a)/(c)/(d)

Requirements: (i) close the aliasing hole, (ii) back-compat with 386 signed
`.intoto` at `sha256/<art>.intoto`, (iii) compose with deployed D1, (iv) no
regression to the signer selfSHA guard / genuine-cycle detection.

- **(a) spec-qualify ResolvedDependency + walk key.** Per the memory caveat, (a)
  ALONE is INERT: the mirror `.intoto` is FETCHED by art-sha, so the walk still
  pulls the poisoned payload. Making it effective requires a spec-qualified STORE
  and FETCH path (`sha256/<art>__<spec_hash>.intoto` or a subpath) — a mirror
  layout change for ALL pkgs => mass migration / re-sign. Fails (ii). Rejected.
- **(c) scope resolvedDeps to the true closure.** Risks under-collecting a real
  transitive dep => a trust HOLE. Rejected (correctness > cleverness; this is the
  attestation root).
- **(d) give bedrock leaves replace_on_cycle breakers.** Orthogonal graph plumbing
  that reduces bloat but does NOT fix last-writer-wins on a shared slot; two clean
  specs still race for one slot non-deterministically. Insufficient alone.
- **(b) leaf-owns-slot.** Preserves art-sha keying + back-compat, is the durable
  form of tonight's manual stopgap, and is write-path-only (orthogonal to the walk,
  satisfying (iv)). Chosen.

## Root cause recap (confirmed cold 2026-07-03)

- Slot `gs://<MIRROR_BUCKET>/sha256/<art>.intoto` is keyed by the REPRODUCIBLE
  artifact sha. Two distinct specs (production `linux_headers`,
  `stage0-linux-headers-6.12.43`) build the identical kernel-6.12.43 UAPI tarball
  => same art-sha 083cdb => ONE slot.
- The signer published it with an unconditional `writeBytes` => LAST-WRITER-WINS.
- A CHAIN_ENFORCE bedrock rung records its cycle-broken closure in
  `resolvedDependencies` (D1) — many edges — whereas a non-enforcing production leaf
  records NONE. When the rung wrote last, a consumer resolving `linux_headers` ->
  083cdb -> the slot recursed into bedrock provenance and hit the breaker-less
  `gmp<->linux-headers` cycle => false cycle => seal fail.
- D1 (ROOT, deployed) fixed WHAT the builder records under CHAIN_ENFORCE
  (`cycle_broken_deps_of`, not raw `transitive_specs_of`). D2 (this) fixes WHO owns
  the shared slot.

## The fix — `mirrorSlotWinner` (signer/main.go)

Signature: `mirrorSlotWinner(incoming *intotoStatement, incomingPayload,
parkedEnvelope []byte, artSHA string) (write bool, reason string)`.

Precedence (LOWER rank wins; a pure function of the SET of envelopes, so the slot
converges to the same winner regardless of write order):

1. Parked slot empty / unparseable / attests a different sha => incoming wins
   (first real writer, or self-repair). Every write already passed the full verify
   pipeline (`verify_token` + `verify_intoto` + `verify_deps`); only the signer SA
   can write the mirror bucket, so overwriting junk is safe.
2. FEWER `resolvedDependencies` wins. Non-CHAIN_ENFORCE builds emit EMPTY
   resolvedDependencies (builder half: `resolved_deps` untouched unless
   CHAIN_ENFORCE=1 — src/main.rs ~1004/1050) => depCount 0. A CHAIN_ENFORCE rung
   records >= 1. So a leaf ALWAYS outranks a rung and a chain-enforce re-sign can
   NEVER evict a leaf.
3. Ties (equal depCount) break on the lexicographically-smaller signed payload
   bytes: deterministic + order-independent.

Wiring in `signerOnce` (publish stage): read back the parked envelope
(`readObject`; a genuine `ErrObjectNotExist` => empty slot; ANY OTHER read error =>
fail the task rather than blind-overwrite, so a transient GCS blip cannot
reintroduce last-writer-wins), then write `sha256/<art>.intoto` only when
`mirrorSlotWinner` returns write=true. The per-pkg release-channel envelope
(`<pkg>-<ver>/...intoto.jsonl`) and the mirror ARTIFACT blob (`sha256/<art>`,
byte-identical across specs) are written unconditionally as before — the artifact
stays fully attested regardless of who owns the shared slot.

### Load-bearing assumption (documented in code)

Soundness rests on: **non-CHAIN_ENFORCE => EMPTY resolvedDependencies** (depCount 0).
This is a real builder invariant (the zero-regression gate at src/main.rs ~995-1054;
`empty_resolved_dependencies_field_omitted` in intoto.rs). The graph test
`leaf_records_empty_closure_rung_records_nonempty` and the intoto test
`leaf_and_enforcing_shapes_are_distinguishable_by_dep_count` pin it on both sides of
the language boundary. If a future change makes a leaf emit phantom deps, revisit
this precedence.

### Why this is trust-neutral

`mirrorSlotWinner` is NOT a trust boundary — it only canonicalizes AMONG envelopes
that already passed the full verify pipeline. Every candidate is a KMS-signed,
approved-builder attestation of the SAME bytes (content-addressed). Picking the
leanest correct proof (empty-deps leaf) keeps production consumers out of bedrock
provenance without weakening any signature or allowlist check. The leaf's empty
`resolvedDependencies` is HONEST for a from-source-tarball build (its inputs are on
`declaredSources`/`bootstrap_deps`), so leaf-ownership never under-collects.

## Back-compat / migration story

- Mirror LAYOUT is unchanged (`sha256/<art>.intoto`). The 386 already-signed
  envelopes are byte-identical and remain valid. No re-sign required for them.
- No in-toto SCHEMA change. `ResolvedDependency` is untouched (candidate (a)'s
  `spec_hash` field was deliberately NOT added — it would change chain-enforce
  envelope bytes and is inert without a layout change).
- First time each shared slot is re-signed after deploy, the read-back precondition
  runs; if a leaf already owns the slot (or the tonight-stopgap clean envelope is
  parked), a later chain-enforce re-sign is now a no-op on the slot. The stopgap
  becomes self-healing rather than fragile.
- Non-shared slots (the overwhelming majority): read-back returns
  ErrObjectNotExist or the identical prior envelope => write / idempotent-keep. No
  behavior change.

## Re-attest cascade implications

- The fix is WRITE-PATH only. It does NOT invalidate any existing envelope. No
  cascade is REQUIRED for correctness.
- To realize the durable property on the KNOWN shared slot (083cdb), re-attest the
  PRODUCTION leaf `linux_headers` once after deploy so its clean empty-deps envelope
  is the canonical parked slot (it already is, via the manual stopgap; re-signing it
  through the fixed signer makes it durable). Do NOT re-attest
  `stage0-linux-headers-6.12.43` for this purpose — a chain-enforce re-sign now
  cannot evict the leaf anyway, and re-signing it is the exact action the fix
  neutralizes.
- Any OTHER content-shared slots discovered later self-heal on the next re-sign of
  whichever spec is the leaf; no bulk cascade.
- Gotcha (from memory): the tcc-musl2 lottery / content-hash aliasing family — after
  deploy, spot-check that R6 (linux-headers) seals for a PRODUCTION consumer, not
  just for the bedrock rung.

## Deploy runbook (for the operator — NOT executed here)

1. Merge both branches `bryan/durable-mirror-spec-qualify`
   (minimermetic signer/builder + graph worktree) into their integration branches.
2. Rebuild the SIGNER image (this is a signer-logic change):
   `orch image-rebuild` (verify it bounces the signer; the builder change is
   test-only so a builder rebuild is optional but harmless). Confirm the signer VM
   comes up RUNNING on the new digest (see memory:
   image_rebuild_leaves_killed_builder_terminated).
3. Re-attest ONLY the production leaf to make the slot durable:
   `orch drop linux_headers && orch enqueue linux_headers` (NON-chain-enforce).
   EXCLUDE `stage0-linux-headers-6.12.43` from re-attest.
4. Verify: fetch `sha256/083cdb....intoto`, confirm it is the empty-deps production
   leaf envelope; run a production consumer's seal (R6) and confirm no false cycle.
5. No trust-config change, no bootstrap allowlist change, no KMS change.

## Test results (host)

- `signer`: `go build ./...` OK; `go test ./...` — all pass EXCEPT the pre-existing
  `TestVerifyDepsRecursive_CycleRejected` (FAILS on baseline too, before this
  change: the selfSHA guard masks a self-ref-as-cycle; see Observations). My 7
  `TestMirrorSlotWinner_*` all pass; `go vet ./...` clean.
- `graph` (worktree): my `leaf_records_empty_closure_rung_records_nonempty` passes.
  5 pre-existing `spec_hasher::*` golden-hash tests FAIL on baseline too (blake3/ncl
  golden drift on this vendored branch) — unrelated.
- `hermetic-builder-rs` intoto test: could NOT run on host — the vendored `stdlib`
  build artifact has a stale hardcoded absolute path
  (`/Users/bryan/workspace/minimalmertic/...`, note the different repo-name
  spelling) baked into a generated `include_bytes!`, and the vendor dir is
  gitignored/rsynced. The test uses the identical API as its passing sibling tests
  in the same module, so it will run on the Linux builder image / CI.

## Observations (out of scope, flagged)

- **Pre-existing signer test failure**: `TestVerifyDepsRecursive_CycleRejected`
  fails on the UNMODIFIED tree. The selfSHA guard (`hash == selfSHA => continue`,
  main.go ~695) skips a self-reference BEFORE the `onPath` cycle check, so a
  self-referential attestation the test constructs is accepted, contradicting the
  test's expectation. Either the guard intentionally supersedes this test (then the
  test should be updated/removed) or the guard is too broad. Worth a decision — it's
  right next to the genuine-cycle detection this task must not regress.
- **Stale generated absolute path** in the vendored `stdlib` build script
  (`minimalmertic` vs `minimermetic`) blocks host `cargo test` of the builder crate.
  A `cargo clean -p stdlib` + re-vendor would fix local iteration.
