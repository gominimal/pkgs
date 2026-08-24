# B4 glibc path — de-risked build plan (workflow `wf_fda125bc-850`, 2026-07-02)

> **UPDATE 2026-07-03:** R12 = gcc-15.2.0 is now BUILT + FUNCTIONAL — the 5-major (10.4→15.2) codegen jump
> PASSED, built on musl via the new `--with-native-system-header-dir=<musl-sysroot>/include` reflex. So the
> "NEXT CONCRETE STEP … build/seal R12" section below and the rung table listing R12 as *future* are DONE for
> the build; only the SEAL remained. R12's seal was blocked by a content-hash ALIASING bug (production
> `linux_headers` ≡ `stage0-linux-headers` share artifact-sha `083cdb` → one mirror slot, last-writer-wins
> poisoned by the stage0 chain-enforce attestation). UNBLOCKED 2026-07-03 via a trust-neutral STOPGAP (copy the
> clean dual-signed production `linux_headers` release envelope over the shared slot); R6 re-sealed, R7–R11 stay
> signed, R12 is rebuilding from the cosigned image (no overlay) and will SEAL when the ~1–3h compile finishes.
> The stopgap is FRAGILE (a re-sign of `stage0-linux-headers` re-poisons the slot) — do NOT re-attest it in any
> cascade. DURABLE fix = spec-qualified mirror keyed on `(spec_hash, artifact-sha)` (issue #14, review-gated).
> Everything else below is still the LIVE B4 strategy; Caveats A + B remain open per ground truth.
> B3 is CLOSED (hex0→gcc-10.4.0 all sealed). glibc-2.42 / B5 / B6 / B7 remain DESIGNED, not built.

11-agent workflow (5 facets × investigate+adversarial-verify + synthesis). **Verdict: GO-WITH-CONDITIONS.**
This is the authoritative B4 execution plan; supersedes the open questions in `b4-glibc-2.42-scoping.md`.

## The headline (answers "will our 368 packages rebuild?")
**HIGH confidence, and the handoff is tiny — because the from-source path is ALREADY the primary recipe.**
All 7 toolchain leaves (gcc/glibc/binutils/gmp/mpfr/mpc/linux_headers) have `cmd="./build.sh"` building the
REAL source tarball; the debian prebuilt blob lives ONLY in each leaf's `replace_on_cycle` cycle-breaker.
Downstream packages `import "../gcc/build.ncl"` by reference and never touch `replace_on_cycle`. So:

- **The 368 package recipes change ZERO lines.** The literal "change as little as possible" ask is not just
  met — it's already the architecture.
- **The entire handoff diff is:** (1) swap `url`+`sha256` in the amd64 arm of `replace_on_cycle.build_deps`
  in **7** `build.ncl` files; (2) relocate the **7** `source/*-prebuilt@*` entries in `trust-config.json`
  from `bootstrap_deps` → `bootstrap_artifacts` (+url +applies_to_packages) so CHAIN_ENFORCE covers them and
  the trust floor collapses to the 229-byte seed. **No hermetic-builder code change.**
- ABI-identity holds: from-source glibc-2.42/gcc-15.2.0 use the byte-identical build.sh that produces today's
  prebuilt leaves (same source shas, same `--enable-kernel=6.1`/`-march=x86-64-v3`/pie/ssp/`--build-id=none`).
  Grep confirmed ZERO production packages do `__GLIBC__` gating or hard-code toolchain identity.

## The real ceiling: toolchain CORRECTNESS, not ABI
The chain has **silently corrupted libc twice** (R4 musl `fmt_fp` long-double→0.00 passed trivial tests;
tcc-mes miscompiles its own ≥4-arg calls). A wrong-but-quiet gcc-15/glibc can compile+link+run hello.c yet
break float formatting / TLS / IFUNC. `--disable-bootstrap` removes GCC's own 3-stage compare tripwire.
→ **Stand up a float/locale/TLS/IFUNC correctness gate at R12 + B4** (does not exist yet) + differential-coreutils.
Consider `--enable-bootstrap` on the BEDROCK gcc rung (self-heals a stage-0 miscompile; ~3× cost) WITHOUT
touching production build.sh.

## Two builder-side unknowns — settle EMPIRICALLY before the B7 flip
- **CAVEAT A — twinning:** `breaker_hydrate.rs` Pass 2 (~:165, guarded by `if cache.read_dir(&non_prebuilt_hash).is_ok() continue`) copies prebuilt bytes into the from-source spec_hash slot ONLY when empty. A
  RemoteCache-carried real B5 build wins, but a mis-config would ship prebuilt bytes under a from-source label.
  **B7 must guarantee the real B5 build populates the slot.**
- **CAVEAT B — spec_hash cascade (UNVERIFIED; gominimal graph crate not on local FS):** does editing
  `replace_on_cycle` change the leaf's spec_hash and cascade a 368 rebuild? If hashed → the flip triggers the
  intended graph-wide rebuild+re-attestation (large event). If NOT (plausible — it's a cycle-break directive,
  not a build input) → the flip invalidates nothing and downstream silently keeps old twinned bytes.
  **Settle with `DUMP_CLOSURE_HASHES` before/after a throwaway edit BEFORE relying on either outcome.**

## Rung sequence
| Rung | What | Risk |
|---|---|---|
| **R12 = stage0-gcc-15.2.0** (musl-linked, built by R11 gcc-10.4.0) — **BUILT+FUNCTIONAL 2026-07-03, sealing** | The modern-gcc gate: glibc-2.42 needs gcc≥12.1, pivot is 10.4. Target **15.2.0 DIRECT** (exact prod version, already mirrored; host-language gate cleared with margin — 10.4's complete C++14/17 vs gcc-15's C++14 floor). Recipe = clone `stage0-gcc-10.4.0/build.sh` + VERSION bump, revalidate 3 copy-forward hazards. | med |
| **B4 = glibc-2.42 COLD multi-pass** | crosstool-NG 4→5→6: install-headers + csu crt → rebuild libgcc against glibc-stage1 (two-pass, safe) → glibc final. Built by R12 + R10 + **image python 3.14.5**. CC wrapper DROPS `-static/-B musl`, KEEPS `-nostdinc`. Single-writer `/usr/lib/glibc-bedrock-2.42`. | **high** |
| **B5 = self-hosting fixed point** | Rebuild gcc-15.2.0 + gmp/mpfr/mpc + **binutils-2.46.0** against from-source glibc, as glibc-linked SHARED libs (`libstdc++.so`/`libc.so.6`/…). First REAL from-source compile of the leaves the 368 link. | med |
| **B6 = determinism proof** | Differential coreutils: compile twice (prebuilt vs bedrock toolchain, both binutils-2.46), byte-diff. Recipes already set `-ffile-prefix-map`+`--build-id=none` → empty diff achievable = strongest cheap "unchanged" proof. | low |
| **B7 = handoff flip** | The 7 `replace_on_cycle` Source swaps + 7 trust-config relocations. 368 recipes UNCHANGED. Gated on Caveats A+B settled. | med |

## NEXT CONCRETE STEP (the smallest increment)
> **DONE 2026-07-03:** R12 gcc-15.2.0 built + functional; the probe hazards below cleared. Now SEALING (aliasing
> stopgap applied; see dated header). Next real increment moves to the glibc-2.42 cold multi-pass. The original
> plan text is preserved below for the record.

**Local configure-probe of the extracted gcc-15.2.0 tree** (hours, no cloud), THEN build/seal **R12**:
- Probe validates the 3 copy-forward hazards before the heaviest `-j1` build yet:
  1. `gcc-15's libstdc++-v3/configure.host` still contains the `os/gnu-linux` token the `os/generic` sed targets;
  2. enumerate gcc-15's full pre-generated set for the Model-B touch-list (`.c`→`.cc` renames, `options.cc`, `gengtype-lex.cc`, bison outputs);
  3. `config/ax_cxx_compile_stdcxx` → confirm `CXX_DIALECT=gnu++14`.
- Build R12 `--disable-bootstrap` first (R11-consistent). **Fallback if it ICEs: gcc-14.3.0 (ALREADY MIRRORED).**
- Attach a float/locale/TLS/IFUNC correctness smoke as a fail-shut gate.

## Python posture
Required + not avoidable (glibc configure aborts without python3; `gen-as-const.py` generates ~15 amd64
`*-as-const.h` compiled INTO libc). **USE the builder-image from-source python 3.14.5** (same as production's
`glibc/build.ncl` python build_dep) — NOT a bespoke stage0-python rung. Lineage stays seed-rooted (python is
orchestration-only; the constants are computed by the seed-rooted CC via `cc -S/-E -dM`). Caveats: `gen-translit.py`
(C-translit.h) is a direct data transform with NO cross-check; wire the `test-as-const` subset into the B4 gate;
pin the exact python minor for B6 determinism.

## Note / correction
B4.1 (`stage0-linux-headers-6.12.43`) was a SEPARATE stage0 proof pkg — it did NOT flip the production
`linux_headers` leaf, whose `replace_on_cycle` still points at the debian prebuilt. linux-headers is the only
genuine standalone flip (libc-independent UAPI); gcc+glibc+gmp+mpfr+mpc flip as a matched set after B5;
binutils flips as a leaf off that set.
