# aarch64 kickoff runbook — execute-on-demand (after amd64/glibc seals)

Companion to issue #12 (native aarch64 MesCC backend) + `.staging-ctx/arm64-notee-feasibility-2026-07-02.md`.
This is the "how do we start" — provision + M0 probe — so aarch64 is a run-these-steps affair once amd64 is done.

## ✅ Verified facts (ground-truth, 2026-07-02)
- **Seeds are FREE:** the already-vendored `gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst` (sha-pinned)
  contains the full AArch64 chain — `AArch64/{hex0,hex1,kaem-minimal}.hex0`, `bootstrap-seeds/POSIX/AArch64/hex0-seed`,
  `AArch64/Development/{M0,catm,hex0/1/2}_AArch64`, and `aarch64.answers` (52 AArch64 entries). **No new source, no
  new mirror upload for M0.**
- **arm64 IS in-region:** GCP **C4A (Axion, Neoverse V2)** is in **us-west1-a** (verified via gcloud) — same region as
  our CS infra (us-west1-c) + mirror buckets. (T2A is NOT in us-west1.) C4A is ARMv9 = native-aarch64-only (no
  AArch32) → perfect for path A / M0; only path B / armhf-transit would need T2A (us-central1), and we chose path A.
- **Swap surface (arch-specific refs per seed rung):** stage0-hex1=4, stage0-kaem=2, stage0-mescc=**106**,
  stage0-mescc-full=36, stage0-mes=47. hex1/kaem are trivial; the bulk (mescc/mes) is M2-Planet + MesCC arch
  selection and needs on-box iteration.

## Phase 0 — provision the box (GCP side)
```bash
export CLOUDSDK_PYTHON=/opt/homebrew/bin/python3.14
gcloud compute instances create bedrock-aarch64 \
  --project minimalmertic --zone us-west1-a \
  --machine-type c4a-standard-16 \
  --image-family debian-12-arm64 --image-project debian-cloud \
  --boot-disk-size 120GB --boot-disk-type pd-balanced \
  --scopes storage-ro \
  --metadata-from-file startup-script=aarch64-startup.sh
```
- **IAM:** grant the instance's service account `roles/storage.objectViewer` on `gs://minimal-staging-archives`
  + `gs://minimalmertic-hermetic-mirror` (for seeds/sources). `--scopes storage-ro` + same-project buckets usually
  suffices; verify with a `gcloud storage cp` on the box.
- **NOT needed (all dropped vs amd64):** Confidential Space image, vTPM, WIF, cosign, signer, attestation. This is a
  plain compute VM outside the trust pipeline.
- **Pulumi:** none for the first probe (scratch box). If it becomes permanent, wrap ONLY the instance + SA in a small
  isolated Pulumi component — carry none of the CS wiring.

### `aarch64-startup.sh` (base toolchain; operator does the repo clone/build — private-repo auth)
```bash
#!/bin/sh
set -ex
apt-get update
apt-get install -y build-essential git curl zstd xz-utils pkg-config libssl-dev
# Rust (aarch64 tier-1) — minimal is built natively on this box, NEVER cross-compiled from Mac
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
```
Then (operator, interactive — keeps clear of the SSH-classifier issue on CS VMs):
```bash
# on the box:
. "$HOME/.cargo/env"
git clone <minimal repo>   && (cd minimal && cargo build --release)   # the minimal CLI, native aarch64
git clone <pkgs repo>      # the pkgs-hermetic-all worktree with the stage0-* recipes
```

## Phase M0 — the seed-swap probe (free, the arch-portability milestone)
**Goal:** `hex0 → hex1 → kaem → M2-Planet` on native aarch64, byte-identical to `aarch64.answers`. Proves the whole
seed/mescc-tools layer ports + the harness runs — with ZERO new codegen.

**Design (per #12): parameterize by `${ARCH}`, don't fork.** Add an `arch` build_arg (default `AMD64`) to the seed
rungs and replace hardcoded `AMD64/` + `hex0_AMD64.hex0` with `${ARCH}/hex0_${ARCH}.hex0`, etc. Then aarch64 = same
recipe with `arch=AArch64`. Concretely:
- `stage0-hex1/build.sh` (4 refs): `AMD64/hex0_AMD64.hex0` → `${ARCH}/hex0_${ARCH}.hex0`; `AMD64/hex1_AMD64.hex0` →
  `${ARCH}/hex1_${ARCH}.hex0`; swap the byte-identity anchor sha to the AArch64 seed's (from `aarch64.answers`).
- `stage0-kaem/build.sh` (2 refs): same `${ARCH}` treatment for the kaem seed.
- `stage0-mescc` (106) + `stage0-mescc-full` (36) + `stage0-mes` (47): the M2-Planet `--architecture aarch64` /
  MesCC arch selection + `MES_ARCH`. Heaviest; expect on-box iteration. M2-Planet's aarch64 backend is upstream-
  complete, so this is wiring, not codegen.
- **Gate:** `sha256sum -c aarch64.answers` at each rung (self-enforcing, no signing infra).
- **Run:** `minimal package stage0-hex1` (then kaem, mescc, mescc-full) on the box, `arch=AArch64`.

**M0 success = a real, publicly re-runnable "the ladder is arch-portable through the seed/mescc-tools layer"
artifact.** Immediately after: a MesCC smoke that CONFIRMS `mescc.scm` lacks an aarch64 target (it will) — converting
the "must write a MesCC backend" decision from assumed → hands-on before committing to the multi-month #12 work.

## Phase M1+ — the real gate (issue #12)
Native aarch64 MesCC backend (`module/mescc/aarch64/{info,as}.scm`) + aarch64 mes-libc (x8/svc syscalls, AAPCS64
va_list, stp/ldp setjmp, crt1). Multi-month; riscv64 backend is the sizing precedent. Do NOT start until M0 is green
+ amd64/glibc is done.

## Claim boundary (unchanged)
arch-portable + reproducible seed-rooted bootstrap, explicitly NOT SLSA-L4 (no ARM Confidential Space; C4A has no
AMD-SEV — that no-SEV fact is itself the crisp demonstration of why L4 is welded to amd64 silicon).
