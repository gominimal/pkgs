# arm64 / no-TEE ladder feasibility (workflow `wf_7b8c33e9`, 2026-07-02)

9-agent workflow (4 facets × investigate+verify + synthesis; musl-verify + synthesis resumed after a
session-quota interruption). **Verdict: GO-WITH-WORK — but the EXACT amd64-direct ladder does NOT port.**

## The load-bearing finding: GNU Mes has NO native aarch64 MesCC backend
Triple-verified against a fresh mes clone at HEAD:
- `module/mescc/` = {armv4, i386, riscv64, x86_64} only — no aarch64.
- `mescc.scm` arch-get-info dispatch (lines 336-337) = x86/x86_64/riscv64 only — no aarch64 clause.
- `lib/` = {arm, riscv64, x86, x86_64}-mes only — no aarch64-mes.
- ROADMAP still lists "Aarch64 support: Mes C Library and MesCC" as an OPEN TODO; no wip branch supplies it
  (`wip-aarch` = 32-bit armv4/armhf; `wip-aarch64-bootstrap` is DELETED).

**Why it's load-bearing:** MesCC (not M2-Planet) is the rung that builds tcc-0.9.26 (janneke's tcc fork is
MesCC-compilable, NOT M2-Planet-compilable — M2-Planet has no float codegen). So the `hex0→mes→tcc` bridge
has **no native aarch64 realization** and must be re-architected. This is the *same* wall live-bootstrap/Guix
hit; it is cleared upstream only via a 32-bit-ARM detour.

## What's FREE (exists upstream, no codegen invention)
- **Whole lower half hex0→M2-Planet**: stage0-posix ships a complete + mature AArch64 seed chain
  (hex0/hex1/hex2/kaem-minimal seeds + full mescc-tools M0_AArch64/cc_aarch64/M1/hex2 + aarch64_defs.M1 +
  `aarch64.answers` gate). **M2-Planet has a first-class native aarch64 backend** (`--architecture aarch64`,
  36 codegen sites) — R0 builds natively with zero new work.
- **tcc's aarch64 codegen backend already exists** (arm64-gen.c/arm64-link.c in mainline 0.9.27; janneke's
  0.9.26 fork ships lib/lib-arm64.c) — the tcc backend need NOT be written, only the kaem/env wiring.
- Upper rungs port modulo triple-swap (mature aarch64 backends): binutils-2.30/2.41, gcc-10.4, musl-1.2.5
  (amd64 patches already dropped at 1.2.5), gmp/mpfr/mpc. "Free" only IF a predecessor rung targets aarch64.
- musl-1.1.24: 5 of 8 amd64 patches transfer verbatim; the 3 amd64-specific ones drop; src/math/aarch64 is
  all-C (safe asm-removal analog).
- **The no-TEE harness decoupling is near-free**: vendor/minimal core (decode/graph/lcache/sandbox2/mctx) is
  TEE-agnostic; every CS stage lives in the hermetic-builder-rs WRAPPER. minimal already models arm64
  (Arch::Arm64, Target::host aarch64 branch, sandbox2 lib64→lib path). Recipe STRUCTURE transfers wholesale.
- **riscv64 is a worked precedent**: mes already has a from-scratch riscv64 MesCC backend + libc contributed
  at single-contributor scale — the concrete sizing estimate for an aarch64 port.

## The gate (Step 2 — the real decision, DEFER until amd64/glibc spine is done)
- **(A, recommended if pursued) author a native aarch64 MesCC backend + aarch64 mes-libc** —
  module/mescc/aarch64/{info,as}.scm codegen + aarch64 mes-libc (x8/svc#0 syscalls, __gr_top/__vr_top
  va_list, setjmp/longjmp stp/ldp d8-d15, crt1) + rediscover the whole A64 tcc/musl codegen-bug class
  (≥4-arg miscompile, varargs, float). The clean, upstream-blessed, "arch-direct" story + a real
  contribution. **Multi-month, ≈ the hardest two-thirds of the amd64 effort redone fresh.**
- **(B) armhf-transit** — reuse Guix's 32-bit-ARM Mes/tcc under AArch32 EL0, cross to aarch64 at gcc-4.8+.
  Least new code (proven prior art) BUT silicon-gated (needs Neoverse-N1: Graviton2/Ampere Altra/T2A/RPi4-5;
  NOT Graviton3+/AmpereOne/Apple Silicon) and produces a **32-bit toolchain** — materially the SAME shape the
  team deliberately rejected on amd64. Yields a WEAKER/different claim. Recommend (A) over (B) if pursued.

The gcc C→C++ bridge is a second HIGH wall under either path: gcc-4.0.4/4.7.4 (the C-only tcc-built keystones)
have NO aarch64 backend (landed gcc-4.8, which needs C++). No native-aarch64 C→C++ gcc bridge below 4.8 →
dissolves only under armhf-transit or an alternative early C++ compiler.

## Cheap FIRST milestone (non-blocking, do later — proves portability without the hard part)
Parameterize + run the LOWER seed rungs for AArch64 — `stage0-{hex1,kaem,mescc,mescc-full}` — swapping the
hardcoded `AMD64/` seed subdir for stage0-posix's `AArch64/` seeds, on a cheap Ampere/Graviton2/RPi5 Linux box
running `minimal` NATIVELY (cargo build --release, aarch64 is Rust tier-1; do NOT cross-compile from Mac).
Success = hex0 → M2-Planet reproduces byte-identically to the answer-files. **FREE (seed swaps only, no new
codegen), a real re-runnable "arch-portable through the seed/mescc-tools layer" artifact.** Then a MesCC smoke
(attempt mes-m2 via M2-Planet on aarch64, confirm mescc.scm lacks an aarch64 target) to convert the
"must-write-a-backend" decision from ASSUMED to hands-on CONFIRMED before committing to the multi-month work.

## Honest claim boundary (do not overstate)
PRESERVED without the TEE: the 229-byte hex0 root, the hakoniwa sandbox, the sha256 byte-identity gates.
LOST: the hardware root of trust / remote-attestable provenance (**SLSA-L4 is categorically impossible on arm
— no ARM Confidential Space; T2A/Ampere has no AMD-SEV**). CRITICAL nuance: "the bootstrap mechanics are
TEE-independent" is TRUE, but the mechanics are NOT arch-portable at the mes→tcc bridge. A *detour-based* arm64
run demonstrates "the 32-bit-ARM ladder runs on aarch64 hardware and cross-climbs" — WEAKER than "the
amd64-direct ladder shape is arch-portable." Only a native-aarch64-MesCC run supports the stronger claim.
**Frame publicly as breadth/portability + reproducibility, explicitly NOT an L4 escalation.**

## Hardware
Primary = **GCP Tau T2A (Ampere Altra / Neoverse-N1)**: reuses existing GCP muscle, keeps AArch32 EL0 (transit
fallback works), and T2A having NO Confidential VM is itself the crisp honest L4-boundary demo. **RPi4/5** =
the tangible "publicly re-runnable on cheap ARM" credibility artifact. AVOID for transit: Graviton3+ (c7g),
Graviton4/ARMv9, AmpereOne, Apple Silicon (dropped AArch32). Apple-Silicon Macs need a Linux guest.

## no-TEE harness change-list
DROP (all in the hermetic-builder-rs wrapper, not minimal): Stage 2 attestation, Stage 5 in-toto, Stage 6
binding-token verify, Stage 7 sign-staging upload, the signer VM + cosign gate, cache-publisher, Pulumi/WIF/
vTPM/GCS-queue (orch/queue_mode). KEEP: hakoniwa sandbox, the mctx/graph/lcache run_build core, the in-build.sh
sha256sum gates. IMPLEMENT via either (A) build `minimal` for aarch64 natively + `minimal package <rung>`, or
(B) a ~150-line local driver over run_build's core minus the 4 CS stages.
