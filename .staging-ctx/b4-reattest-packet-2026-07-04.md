# B4 RE-ATTEST PACKET — the parked libc.so sed fix rides the B7 cascade

Written 2026-07-04. Companion to:
- `.staging-ctx/b4-libc-so-sed-fix.patch` (the PARKED fix — `$PUB` staging prefix → `/$PUB_REL` runtime prefix in `packages/glibc-bedrock-2.42/build.sh:168`)
- `.staging-ctx/b7-flip-plan-2026-07-03.md` (flip diffs; Caveat B = leaf swap cascades ~368-pkg re-attest)
- Cascade mechanics (memory `r5_binutils_progress`): `.intoto` deletes are CLASSIFIER-GATED; signer is
  sha-IDEMPOTENT; re-attest DETERMINISTIC rungs only; **NEVER re-attest stage0-linux-headers-6.12.43**
  (a chain-enforce re-sign of it used to re-poison the shared 083cdb slot; leaf-owns-slot now guards
  the slot, but the standing exclusion stands — there is no reason to ever re-sign it).

Standing state (2026-07-04): B4 glibc-bedrock-2.42 SEALED (subject `7a339324`, 535 deps) **with the
poisoned libc.so** — its versioned `$SR/lib/libc.so` linker script bakes `GROUP(/build/output/...)`
staging paths. B5 rung 1 binutils-2.46-glibc SEALED against it via consumer-side FIXLIB;
gcc-15.2.0-glibc iterating with the same FIXLIB. The patch CANNOT be committed standalone: it changes
glibc-bedrock-2.42's build_script bytes → new `spec_hash` → every sealed B5 envelope's chain walks a
B4 slot that no longer matches the graph → the B5 chain is orphaned and must re-seal for zero
user-visible benefit.

---

## 1. WHEN to apply the patch — VERDICT: with the B7 window, CONFIRMED, with one refinement

**Confirmed:** applying the patch with the B7 flip is correct, because the flip already re-hashes and
re-attests the entire catalogue (Caveat B, flip plan §3) — the B4 spec_hash change the patch causes is
strictly dominated by the flip's cascade. Committing it any earlier buys nothing (every B5 consumer
already carries FIXLIB, which fully neutralizes the defect at link time) and costs a full
B4→B5 re-seal cycle on its own.

**Refinement (proposed better): apply it at the HEAD of the B7 window, BEFORE B6 and BEFORE filling
the flip placeholders — not literally "in the flip commit."** Two reasons, both load-bearing:

1. **The flip placeholders DEPEND on the patched artifact.** `<B4_GLIBC_SHA>`/`<B4_GLIBC_URL>` in the
   flip plan must be filled from the sealed release-channel output. The patch changes libc.so bytes →
   the outer tarball sha changes → the value that goes into the 7-leaf `replace_on_cycle` swap and
   `bootstrap_artifacts` is only knowable AFTER the fixed B4 re-seals. So the strict order inside the
   window is: **commit patch → re-seal B4→B5 chain (§2) → fill placeholders from the NEW shas →
   flip commit → catalogue cascade.** One committed patch, one cascade, two commits.
   ⚠ Anti-footgun: after re-seal, `grep -r 7a339324` the flip diffs — the OLD B4 sha must appear
   nowhere. Shipping the flip against the old (poisoned) B4 sha would push the `/build/output/...`
   defect into every catalogue consumer's breaker slot, where NO FIXLIB exists.
2. **B6 should validate the bytes B7 ships.** B6 (differential empty-diff, `b6-differential-plan`) has
   not run yet. If the patch lands after B6, B6 certifies a toolchain whose B4 differs from the one B7
   deploys (expected inert — FIXLIB makes B5 link inputs byte-identical either way — but "expected
   inert" is exactly what B6 exists to prove, not assume). Sequence: patch → re-seal → B6 → flip.

Do NOT bundle the patch and the flip edits in a single commit: the patch must be vendored + built +
re-sealed before the flip's placeholder values exist. (Also matches the operator's
one-architectural-increment-per-commit preference.)

---

## 2. Exact re-seal order — no chain-enforce walk ever sees an unattested dep

Rule (proven at s4/R4b and the R6 cascade): a `--chain-enforce` consumer requires EVERY
resolvedDependency independently attested BEFORE it is enqueued. Therefore strictly serial,
gated on `done ✔` (release envelope + mirror `.intoto` present) at each step.

**Step 0 — vendor.** Commit the patch (pkgs-hermetic-all), `orch image-rebuild --target rust-builder`,
verify digest CHANGED, deploy, verify builder RUNNING on the new digest AND signer bounced
(`EXPECTED_BUILDER_IMAGE_DIGEST` fresh — orch does both since 0d8f3af, verify anyway). Image-vs-pkgs-HEAD
drift has bitten 3+ times; the re-seal is trust-grade only from the vendored image, no overlays.

**Step 1 — `glibc-bedrock-2.42` (B4).** `orch enqueue glibc-bedrock-2.42 --chain-enforce`.
- Its OWN deps (R12 gcc-15.2.0, R10 binutils-2.41, spine, linux-headers) are untouched by the patch —
  their spec_hashes are stable and their envelopes already sealed → the walk terminates cleanly.
- New spec_hash → RemoteCache miss → genuine rebuild; fixed libc.so → **NEW artifact sha** → fresh
  `sha256/<new>.intoto` slot; signer's sha-idempotency never engages. **No `.intoto` deletion needed
  for B4.** Old slot `7a339324` is left untouched (historical chains for the v1 B5 envelopes keep
  resolving).
- Post-seal gate (before Step 2): extract the artifact,
  `grep -c '/build/output' usr/lib/glibc-bedrock-2.42/lib/libc.so` must be 0 and GROUP paths must be
  `/usr/lib/glibc-bedrock-2.42/lib/{libc.so.6,libc_nonshared.a,ld-linux-x86-64.so.2}`. Record the new
  outer-tarball sha → this is `<B4_GLIBC_SHA>`.

**Step 2 — `binutils-2.46-glibc`.** Enqueue `--chain-enforce` only after Step 1 is `done ✔`.
- Its closure contains B4 → spec_hash changed by Step 1 → real rebuild against the fixed sysroot.
- **Sha-idempotency fork:** FIXLIB made the v1 link inputs identical to the fixed ones, and the recipe
  is determinism-hardened (`--build-id=none`), so the rebuilt artifact sha MAY equal the sealed v1 sha.
  - If sha is NEW → fresh slot, fresh envelope, nothing to do.
  - If sha is UNCHANGED → the signer no-ops and the existing envelope (which cites OLD-B4 `7a339324`
    in resolvedDependencies) stays. That is still walk-valid (old B4 envelope remains attested and
    seed-rooted), but for clean lineage delete `sha256/<binutils-art>.intoto` (CLASSIFIER-GATED —
    operator approves the `gcloud storage rm`; record the object generation first; bucket soft-delete
    = 7 days, recovery `gcloud storage restore <obj>#<gen>`), then drop+enqueue → re-signs at the SAME
    sha with the new-B4 dep. This satisfies the "deterministic rungs only" cascade rule — binutils IS
    deterministic; verify the `.intoto` reappears at the same sha.
- Recommendation: take the delete+re-sign branch. B7's post-flip audit greps consumer chains; a
  mixed old-B4/new-B4 lineage is auditable noise you don't want in the 368-pkg cascade.

**Step 3 — `gcc-15.2.0-glibc` (B5 fixed point).** Enqueue `--chain-enforce` after Step 2 `done ✔`.
Same sha-idempotency fork and same resolution as Step 2 (its CFLAGS_FOR_TARGET paths also went through
FIXLIB, so byte-stability is plausible). It consumes BOTH B4 and binutils-2.46-glibc — both now
attested with fixed lineage before its walk starts.

**Step 4 — `gmp-glibc` (then `mpfr-glibc` → `mpc-glibc`, in that dep order — scaffolded 2026-07-04,
all three build.ncl+build.sh exist).** Enqueue after Step 3 `done ✔`. Chain facts (verified against
their build.ncl imports 2026-07-04): their CC is R12 `stage0-gcc-15.2.0` (NOT gcc-15.2.0-glibc);
they consume B5 `binutils-2.46-glibc` + B4 `glibc-bedrock-2.42`, so strictly they only need Steps
1-2 `done ✔` — gating on Step 3 is conservative slack, kept for one-frontier-at-a-time simplicity.
mpfr additionally needs gmp-glibc, mpc needs gmp+mpfr → strictly gmp → mpfr → mpc, each gated on the
previous `done ✔`. These produce `<B4_GMP_SHA>`/`<B4_MPFR_SHA>`/`<B4_MPC_SHA>` for the flip.

**Exclusions (permanent):** `stage0-linux-headers-6.12.43` — NEVER enqueue, NEVER delete/rewrite its
shared `083cdb` slot (leaf-owns-slot protects it now, but it also never needs re-attesting: the patch
does not touch it, its spec_hash is unchanged, and `<B4_LINUXHDRS_*>` comes from the production-leaf
envelope per the durable-fix deploy note). `stage0-tcc-0.9.27-musl-s4` (lottery, non-deterministic) —
not in this chain anyway; listed for completeness of the exclusion list.

Why no consumer ever sees an unattested dep: at every step N, the only spec_hash-changed nodes are
exactly steps 1..N−1, all `done ✔` before N enqueues; everything below B4 is untouched and already
sealed. The serial gating is the entire mechanism — do not batch-enqueue these four.

---

## 3. FIXLIB verdict: **INERT, keep them (do not remove in this window)** — verified mechanically

The FIXLIB block (identical in `packages/binutils-2.46-glibc/build.sh:52-55` and
`packages/gcc-15.2.0-glibc/build.sh:55-58`):

```sh
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B5 infra: libc.so fixup failed" >&2; exit 1; }
```

Verified 2026-07-04 against the FIXED script content (simulated: canonical glibc-2.42
`GROUP ( /usr/lib/libc.so.6 /usr/lib/libc_nonshared.a AS_NEEDED ( /usr/lib/ld-linux-x86-64.so.2 ) )`
run through the patched B4 sed `s@/usr/lib/@/$PUB_REL/lib/@g` with
`PUB_REL=usr/lib/glibc-bedrock-2.42`, then through the FIXLIB sed with `SR=/usr/lib/glibc-bedrock-2.42`):

- Fixed B4 output: `GROUP ( /usr/lib/glibc-bedrock-2.42/lib/libc.so.6 ... )` — correct runtime paths.
- FIXLIB over that: the regex `[^ ()]*/(libc\.so\.6|...)` greedily eats the whole absolute prefix and
  rewrites it to `${SR}/lib/\1` = `/usr/lib/glibc-bedrock-2.42/lib/\1` — **byte-identical output**
  (`diff` empty). The `/build/output` guard passes. The design comment in the recipes
  ("prefix-agnostic, idempotent once B4 is re-attested with the fix") is CONFIRMED, not just claimed.

Verdict: after the fixed B4 lands, FIXLIB degrades to a byte-copy of `$SR/lib/libc.so` into a
redundant `-L` dir — fully inert, zero correctness effect. **Do not remove it in this window**, even
though removal would be "free" (the B5 recipes re-hash and re-seal in Step 2/3 regardless):
1. The `grep -q '/build/output'` guard is a live fail-loud tripwire against this exact defect class
   regressing in any future B4 edit — that is worth keeping indefinitely.
2. Removal changes B5 build_script bytes at the same moment as the B4 cascade — one more variable in
   a trust-critical window, against the DO-NOT-RUSH rule. If desired, strip FIXLIB (keeping the guard
   as a bare assertion on `$SR/lib/libc.so` itself) in a LATER commit that rides some future re-seal.
3. Caveat: FIXLIB is inert only for `libc.so`. It never covered anything else (libm.so was never
   poisoned — the buggy sed targeted only libc.so), so nothing else changes.

---

## 4. Leaf-owns-slot interaction — no shared-slot hazards, CONFIRMED

- **New bytes → new slot.** The fixed libc.so differs from v1 → the outer tarball sha differs →
  B4's re-signed envelope lands at a brand-new `sha256/<new-art>.intoto`. Nothing else in the universe
  produces those bytes (versioned-sysroot path + from-source compiler baked in) → no content-hash
  aliasing, `mirrorSlotWinner` never has to arbitrate. The one historical aliasing case
  (stage0-linux-headers ≡ production linux_headers at `083cdb`) is not touched by this cascade
  (Step-order §2 excludes it) and is guarded by leaf-owns-slot anyway (a chain-enforce rung with 500+
  deps can never evict the zero-dep production leaf).
- **Old slot stays coherent.** `7a339324.intoto` remains, still owned by the v1 B4 envelope; the
  sealed v1 B5 envelopes that cite it keep resolving. No last-writer-wins overwrite occurs because the
  new envelope writes to a different key. (This is also why the patch is safe to apply at all: the
  mirror is append-shaped under content addressing; re-attesting deterministically either lands in a
  new slot or re-signs the same slot with the read-back precondition.)
- **The one idempotency wrinkle is B5, not B4** (§2 Step 2/3): if a B5 rung reproduces its v1 artifact
  sha, its slot is SHARED between v1-lineage and v2-lineage envelopes of the SAME producer. That is
  not aliasing (same spec, same bytes) and leaf-owns-slot's fewest-deps rule is a no-op between two
  chain-enforce payloads of similar dep counts — but it IS last-writer-relevant, which is why the
  §2 recommendation is an explicit classifier-gated delete + re-sign, then verify the `.intoto`
  reappears at the same sha with the new-B4 dep inside.
- **Flip-side check:** the B7 `bootstrap_artifacts`/`replace_on_cycle` values must cite the NEW slot's
  release-channel object. After the flip, the old prebuilt blobs AND the v1 B4 release object become
  dead trust surface; delete only after the post-flip audit (flip runbook step 9).

---

## 5. Dry-run checklist (all local/cheap; run before Step 0 of §2)

- [ ] **Sed simulation** (already run 2026-07-04, re-run to taste): patched sed + FIXLIB sed over a
      canonical libc.so script → fixed output has `/usr/lib/glibc-bedrock-2.42/lib/` GROUP paths;
      FIXLIB output byte-identical; `/build/output` guard passes. (Scratchpad recipe in this packet §3.)
- [ ] **Ground truth against real bytes:** extract the SEALED v1 B4 artifact's `libc.so`, apply the
      patched sed to the pristine `$OUTPUT_DIR/usr/lib` form, confirm the same three filenames and no
      other `/usr/lib/` occurrences get rewritten (e.g. comments), and the FIXLIB idempotency holds on
      the REAL script, not just the simulated one.
- [ ] **Cascade scope proof (DUMP_CLOSURE_HASHES):** on a scratch branch with the patch applied,
      `DUMP_CLOSURE_HASHES=1` before/after over the closures of glibc-bedrock-2.42,
      binutils-2.46-glibc, gcc-15.2.0-glibc, and one NON-consumer bedrock rung (e.g. R10). Expect:
      the three B4/B5 lines change; R10, the spine, and **stage0-linux-headers are byte-stable**
      (proves the patch cannot drag the forbidden rung into the cascade). Revert the scratch edit.
- [ ] **Exclusion audit:** whatever enqueue script/list drives §2 contains exactly
      {glibc-bedrock-2.42, binutils-2.46-glibc, gcc-15.2.0-glibc, gmp/mpfr/mpc-glibc-when-scaffolded}
      and does NOT contain stage0-linux-headers-6.12.43 or any lottery rung.
- [ ] **Soft-delete safety net:** confirm mirror bucket soft-delete (7-day) still enabled; for any
      planned `.intoto` delete (§2 Step 2/3 fork), record `gcloud storage objects describe` generation
      numbers FIRST.
- [ ] **Vendor gate rehearsal:** `minimal check glibc-bedrock-2.42` (and both B5 pkgs) clean on the
      patched tree; confirm the patch applies cleanly to current HEAD (`git apply --check
      .staging-ctx/b4-libc-so-sed-fix.patch` in the worktree).
- [ ] **Post-B4-seal gates staged** (from §2 Step 1): artifact-extract grep script ready; a note to
      record the new outer sha into the flip plan's placeholder table.
- [ ] **Old-sha tripwire staged:** `grep -rn 7a339324` to run over the final flip diffs before the
      flip commit (must be empty).
- [ ] **B6 ordering confirmed with operator:** patch → §2 re-seal → B6 empty-diff → placeholder fill →
      flip. If the operator prefers B6-first (e.g. B6 already in flight), that is acceptable —
      FIXLIB byte-identity means the B5 toolchain is unchanged — but record the deviation in the B6 doc.

---

## Observations (beyond scope)

- **The B5 rungs may be the first real test of B5 determinism.** If Step 2/3 reproduce their v1
  artifact shas byte-for-byte, that is a free, earlier-than-B6 confirmation of the `--build-id=none`
  determinism work — worth recording as a B6 pre-signal either way.
- **`gmp-glibc`/`mpfr-glibc`/`mpc-glibc` are now scaffolded** (2026-07-04; recipes exist, unbuilt/
  unsealed) — the earlier "NOT scaffolded" long-pole concern is resolved at the recipe level; the
  remaining pole is building+sealing them inside the §2 order. They gate three of the flip
  placeholders (`<B4_GMP_SHA>`/`<B4_MPFR_SHA>`/`<B4_MPC_SHA>`).
- **The `2>/dev/null || true` on the B4 sed (kept by the patch) is a silent-failure vector:** if
  libc.so were ever missing or the sed failed, B4 would seal with an unpatched script and only a
  CONSUMER would notice (exactly how the original bug shipped). The B5-side grep guard catches the
  known pattern, but a producer-side assertion in glibc-bedrock's build.sh (grep the published libc.so
  for `GROUP ( /usr/lib/glibc-bedrock-2.42/lib/`) would fail-loud at the source. One-line, and it can
  ride the same patch commit without extra cascade cost — recommend adding it when the patch lands.
- **The flip plan's `<B4_GLIBC_SHA>` provenance note should say "from the RE-SEALED (post-patch) B4":**
  as written, someone executing `b7-flip-plan` §4.1 could fill it from today's sealed `7a339324` and
  ship the poisoned libc.so to all 368 consumers (which have no FIXLIB). Suggest annotating the flip
  plan's placeholder table to point at this packet.
