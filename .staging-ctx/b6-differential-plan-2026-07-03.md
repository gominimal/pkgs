# B6 — Differential-Coreutils Empty-Diff Proof Plan

**Date:** 2026-07-03
**Author:** recon subagent
**Goal:** Prove that a production package compiled against the **from-source B5 toolchain**
(gcc/glibc/binutils/linux_headers built from real source) is **byte-identical** to the same
package compiled against the **prebuilt-Debian cycle-breaker toolchain** — i.e. that the
bedrock rebuild did not change the emitted artifact. PASS = empty diff.

---

## 0. TL;DR / verdict up front

The differential mechanism is already structural (leaf `replace_on_cycle` prebuilt vs
from-source populating the same `spec_hash` slot), and **coreutils is the correct pilot**:
small, from-source C, glibc-linked, and it already carries every determinism knob.

**BUT the naive byte-empty-diff CANNOT pass today** because the two toolchains are not the
same compiler version:

- from-source target (`packages/gcc/build.ncl:30`) = **gcc 15.2.0**
- prebuilt cycle-breaker blob (`packages/gcc/build.ncl:135-142`) = **gcc 12.4.0**
  (amd64 sha `90c1cc36…`, arm64 literally `gcc_12.4.0_arm64-linux-gnu_prebuilt.tar.zst`)

A 3-major gcc codegen gap changes instruction selection/scheduling/inlining. The
determinism knobs neutralize *path/build-id/timestamp/switch-note* nondeterminism; they
**cannot** erase a compiler-version codegen delta. Same applies to glibc CRT/headers
(from-source glibc-bedrock-2.42 vs whatever libc the prebuilt gcc-12 links).

**Therefore B6 has two honest framings — pick ONE before starting:**

- **B6-strict (true empty-diff):** make BOTH sides use the **same compiler version.**
  Either (a) stage a **gcc-15.2.0 prebuilt** cycle-breaker so prebuilt==from-source
  version, or (b) run the differential as *from-source-gcc-15 twice* (determinism check,
  not prebuilt-vs-source). Only (a) actually proves the bedrock-vs-Debian invariant.
- **B6-triage (version-honest):** accept a non-empty diff and use `diffoscope` to prove
  every delta is attributable to the known gcc-12→15 codegen difference and **zero** deltas
  are nondeterminism (paths, build-ids, timestamps, symbol order). PASS = "diff set ⊆
  expected-codegen; nondeterminism set = ∅".

Recommendation: **ship B6-triage now** (it is achievable this week and is the load-bearing
trust claim — "no hidden nondeterminism"), and **schedule B6-strict** once a gcc-15.2.0
prebuilt cycle-breaker is staged (that also de-risks the B7 flip). Document which one the
North-Star row is claiming; do not let "empty diff" imply strict if we shipped triage.

---

## 1. Pilot package

**coreutils** — `/Users/bryan/workspace/worktrees/pkgs-hermetic-all/packages/coreutils/`

Why it is the right pilot:

- Small, from-source C (single `configure && make` — `build.sh` is 22 lines).
- glibc-linked, statically deterministic set of binaries; exercises the full
  gcc+glibc+binutils+linux_headers toolchain closure.
- Imports the 7 toolchain leaves **by reference** (`build.ncl:19-22`) so the differential
  is driven entirely by which bytes populate the leaf `spec_hash` slots — no recipe fork.
- Already carries every determinism knob (see §4). No recipe edits required for the proof.

Fallback pilots if coreutils' 100+ binaries make triage noisy: **hello** (one binary,
trivial) as a smoke pilot, or **diffutils** (mid-size). Do the smoke pilot first to
validate the harness end-to-end before the full coreutils run.

---

## 2. The two build paths

Same recipe, same source, same flags. The **only** variable is which toolchain bytes fill
the 7 leaf slots (gcc, glibc, binutils, linux_headers, + gmp/mpc/mpfr transitively).

- **Path ii — prebuilt-Debian (today's default):** `breaker_hydrate.rs` Pass 2 ("twinning",
  ~line 165) copies the `replace_on_cycle` prebuilt blob into the from-source leaf's empty
  `spec_hash` slot. Build coreutils on **current `main`** → **artifact A**.
- **Path i — from-source B5:** the real from-source leaves (gcc-15.2.0, glibc-bedrock-2.42,
  binutils-2.46) win their slots via RemoteCache. Build coreutils on a **throwaway branch**
  where those from-source leaves are populated (or the B7 flip applied) → **artifact B**.

**CAVEAT A (the silent-empty-diff hazard — `breaker_hydrate.rs` ~:165):** twinning only
fills the from-source slot *when it is empty*. If the B5 from-source leaf did NOT actually
populate its slot in RemoteCache, twinning silently ships **prebuilt bytes under the
from-source label** — artifact B is then secretly artifact A and the diff is *falsely*
empty. **This makes an empty diff meaningless unless we independently prove B built
against from-source bytes.** Mitigation in §5 (Gate 0).

**CAVEAT B (spec_hash cascade):** touching any leaf recipe re-hashes its `spec_hash`, which
cascades to coreutils' closure hash. Ensure the only difference between the A-branch and
B-branch closures is the *populated toolchain bytes*, not incidental recipe churn.

---

## 3. How to build it twice

Do NOT reuse the existing `signer` repro comparator — `runReproCheck` (signer/main.go
~1387-1431, Stage-7 ~2170) reruns the **identical** closure on builder-b and asserts equal
sha. That proves intra-pipeline determinism (same deps → same bytes), not toolchain-swap
invariance, and it is currently **disabled** (single-builder policy; `useSignerRepoCheck=false`).
B6 needs a **closure-differential** harness that varies only the 7 toolchain leaves.

Procedure (operator, via `orch`):

1. **Branch A (prebuilt):** on current `main`, enqueue `coreutils`. Let it build against the
   twinned prebuilt toolchain. Fetch artifact + attestation:
   `orch verify coreutils` → record `artifact_sha256` = **shaA**; pull the tarball.
2. **Branch B (from-source):** on a throwaway branch, ensure the B5 from-source leaves are
   the populating bytes (either the B7 url/sha swap applied to the 7 leaf `build.ncl`s, or
   confirm RemoteCache holds the from-source leaf outputs). Enqueue `coreutils`, fetch
   artifact → **shaB**; pull the tarball.
3. Both builds MUST use the identical `build.sh` (§4 knobs), identical source tarball
   (`coreutils-<ver>.tar.xz`, sha-pinned in build.ncl `Source`), identical `-march`,
   identical arch (amd64), identical builder image digest.

Keep the two artifact tarballs side by side for §5 comparison.

---

## 4. Determinism knobs (already present — verify, do not add)

All confirmed in `packages/coreutils/build.sh:12-13,21`:

| Knob | Source line | Neutralizes |
|---|---|---|
| `-ffile-prefix-map=$(pwd)=/builddir` | CFLAGS :12 | build-path strings baked into binaries/debuginfo |
| `-Wl,--build-id=none` (CFLAGS **and** LDFLAGS) | :12, :13 | ELF `.note.gnu.build-id` (hash of inputs → nondeterministic) |
| `-gno-record-gcc-switches` | CFLAGS :12 | `.GCC.command_line` / compiler-flags note |
| `make DESTDIR=$OUTPUT_DIR install-strip` | :21 | symbol tables, mtimes-in-symtab |
| fixed `-march=x86-64-v3 -O3 -pipe` | :8, :12 | ISA/opt-level codegen drift between runs |
| `FORCE_UNSAFE_CONFIGURE=1` | :16 | configure refusing root, not a determinism knob but required |

Residual nondeterminism sources to watch (neutralize in the *comparison*, §5, not the recipe):

- **Timestamps in archive metadata:** if the artifact is a tar, member mtime/uid/gid can
  differ. Compare **extracted file contents**, not raw tar bytes; or normalize with
  `tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner` when re-packing.
- **Build-id:** already `none`; verify with `readelf -n <bin> | grep -i build-id` → empty.
- **`__DATE__`/`__TIME__` macros:** coreutils does not embed them, but confirm `strings`
  shows no date. (If any pkg did, add `-Wno-builtin-macro-redefined -D__DATE__=…`.)
- **Filesystem ordering / `ar` symbol tables:** `install-strip` + deterministic `ar`
  (binutils `D` flag default in 2.46) handle static libs; coreutils ships no `.a`.
- **Locale/`LC_ALL`:** pin `LC_ALL=C` in the harness so any sort inside the build is stable.

---

## 5. How to compare bytes + PASS criterion

**Gate 0 — provenance (defeats CAVEAT A, do this FIRST):** prove artifact B actually built
against from-source toolchain bytes. Inspect the two in-toto attestations' `resolvedDependencies` /
`spec_hash` for the gcc/glibc/binutils leaves: **shaA's toolchain slot = prebuilt blob sha
(gcc `16a7b18a…`), shaB's = from-source gcc-15.2.0 output sha.** If they are equal, twinning
silently used prebuilt on both sides — **abort, the diff is not a differential.**
(Note: in-toto `reproducible` field is hard-coded `false` today — `intoto.rs:114`,
`main.rs:378` — so do not rely on it; read the dependency shas directly.)

**Compare (byte level):**

1. `sha256sum artifactA.tar artifactB.tar` — if equal AND Gate 0 passed → strict empty diff
   (only possible under B6-strict / matched gcc version).
2. Extract both; per-file `sha256`:
   `diff <(cd A && find . -type f -exec sha256sum {} + | sort) <(cd B && ...)`.
3. For any differing file, triage with in-tree **diffoscope** (v306,
   `packages/diffoscope/build.sh` → `/usr/bin/diffoscope`):
   `diffoscope A/usr/bin/ls B/usr/bin/ls`. Classify each delta:
   - **expected-codegen** (instruction selection/scheduling/inlining, register alloc) →
     attributable to gcc-12→15. Acceptable under **B6-triage**.
   - **nondeterminism** (embedded path, build-id, timestamp, symbol/section reordering,
     uninitialized padding) → **FAIL**, fix the knob/harness and re-run.

**PASS criteria:**

- **B6-strict PASS:** Gate 0 passes (B built from-source) AND `shaA == shaB` (empty diff).
- **B6-triage PASS:** Gate 0 passes AND for every differing binary, diffoscope shows the
  delta set ⊆ {expected gcc-12→15 codegen} AND the nondeterminism delta set = ∅ across ALL
  files (no build-id, no path leak, no timestamp, no reordering).

Record the verdict, both shas, both toolchain-slot shas, and (for triage) the diffoscope
summary into the North-Star B6 row. Do NOT let the row read "empty diff" if only triage
passed — say "triage: only-expected-codegen, zero nondeterminism".

---

## 6. Expected non-determinism sources & neutralization (summary)

| Source | Present in coreutils? | Neutralized by |
|---|---|---|
| ELF build-id | yes (default) | `-Wl,--build-id=none` (already set) |
| Build-path strings | yes | `-ffile-prefix-map` (already set) |
| gcc switches note | yes | `-gno-record-gcc-switches` (already set) |
| Symbol tables / debug | yes | `install-strip` (already set) |
| tar member mtime/uid/gid | maybe | compare extracted contents, or `--sort=name --mtime=@0 --numeric-owner` |
| `__DATE__/__TIME__` | no | (verify with `strings`; add `-D` if ever needed) |
| Locale-dependent sort | possible | `LC_ALL=C` in harness |
| **Compiler VERSION codegen** | **YES (gcc 12 vs 15)** | **NOT neutralizable — this is the B6-strict blocker; drives strict-vs-triage choice** |
| glibc CRT/headers (2.42 vs prebuilt libc) | yes | matched only under B6-strict; triage classifies as expected |

---

## 7. Concrete step list

1. Decide **B6-strict vs B6-triage** (default: triage now, strict later once a gcc-15
   prebuilt is staged). Record the decision in the North-Star row.
2. Smoke-pilot with **hello** (1 binary) to validate the two-build harness + Gate 0 +
   diffoscope end-to-end.
3. Build **coreutils** path A on `main`; `orch verify` → shaA + prebuilt toolchain slot sha.
4. Build **coreutils** path B on throwaway branch (from-source leaves populate slots);
   `orch verify` → shaB + from-source toolchain slot sha.
5. **Gate 0:** confirm the two toolchain slot shas differ (else abort — twinning collision).
6. Compare: `sha256sum` → per-file sha → diffoscope triage of differences.
7. Verdict per §5 PASS criteria; write shas + toolchain slots + diffoscope summary to the
   B6 row.
8. (Strict follow-up) stage gcc-15.2.0 as the prebuilt cycle-breaker, re-run for a true
   `shaA == shaB` empty diff; this doubles as B7-flip de-risk.

---

## Observations (beyond scope)

- **The determinism knobs are copy-pasted per recipe, not centralized.** coreutils, and per
  the B4 plan every leaf, independently sets the same `--build-id=none` / `-ffile-prefix-map`
  / `-gno-record-gcc-switches` / `install-strip` block. A single missed knob in one pkg is a
  silent nondeterminism leak that B6 would only catch for the one pilot. Worth a lint
  (`orch` subcommand) that asserts the determinism-knob set is present in every from-source
  C recipe — cheap, and it turns B6's proof into a fleet-wide invariant.
- **`intoto.rs` `reproducible=false` is hard-coded.** Once B6 (even triage) passes for a
  pkg, there is no field to record that the differential was run. Consider a
  `differential_verified` provenance field so the trust claim is machine-checkable per
  artifact, not just a doc row.
- **Gate 0 is the real deliverable.** The empty diff is almost a formality once you *know*
  the two builds used different toolchain bytes; the twinning silent-fallback (CAVEAT A) is
  the thing that can make the whole proof a no-op. I'd invest harness effort there first —
  a `orch differential coreutils` subcommand that refuses to compare unless the two
  toolchain-slot shas differ.
