# packages/rustc-1.91.1 — RUNG 2 of 5 (issue #17)

Build rustc **1.91.1** with our CS-attested rustc **1.90.0** (RUNG 1) as the x.py stage0, fully
offline, installed to a **private versioned prefix** so the next rung can consume it. This is the
second of five rungs that chain up from 1.90.0 to the version `packages/rust` currently seeds:

```
RUNG 1  mrustc-rustc-1.90.0   mrustc  -> rustc 1.90.0            [DONE, CS-attested]
RUNG 2  rustc-1.91.1  (THIS)  1.90.0  -> x.py -> rustc 1.91.1
RUNG 3  rustc-1.92.0          1.91.1  -> x.py -> rustc 1.92.0
RUNG 4  rustc-1.93.1          1.92.0  -> x.py -> rustc 1.93.1
RUNG 5  rustc-1.94.0 (see ⚠)  1.93.1  -> x.py -> rustc 1.94.0
then    packages/rust deletes seed-*.tar.gz and consumes RUNG 5 as stage0.
```

## The stage0 wiring (the deciding mechanism)

`bootstrap.toml [build] rustc = <path>` / `cargo = <path>` makes x.py use those binaries as the
stage0 snapshot **instead of downloading** the `src/stage0` version — the load-bearing offline
mechanism, proven by a signed recipe: `packages/rust/build.sh:38-39` injects exactly those two
keys and `packages/rust` builds+signs even though its stage0 (1.94.1) differs from that source's
`src/stage0` pin (1.94.0) — i.e. the pinned download did **not** occur. This rung bakes the pins
directly (no sed) at `build.sh` P1, pointing at the previous rung's installed prefix:
`/usr/lib/mrustc-rust-1.90.0/bin/{rustc,cargo}` (a build_dep, **not** extracted seed tarballs).
`build.sh` P0 asserts the stage0 `--version` contains `1.90.0` and `--print sysroot ==` the prefix
before firing, so a wrong/absent stage0 fails in seconds.

## Files in this rung

| file | role |
|---|---|
| `build.ncl` | recipe: stage0 = `mrustc-rustc-1.90.0` build_dep, system-LLVM env, no `needs` block, one recursive `OutputData` glob over `usr/lib/rustc-1.91.1/**` |
| `build.sh` | the SYNTHESIS: packages/rust x.py core + RUNG 1 offline harness (P0b) + **vendored-submodule markers (P0c)** + functional gates (P5). Self-contained; gates heredoc'd inline. |
| `gatelib.rs`, `gatestd.rs`, `gate_pm.rs`, `gate_pm_use.rs` | AUDIT copies of the inline gate bodies (source of truth for the heredocs) |
| `rustc-1.91.1.answers` | self-arming byte-seal slot, ships `# UNPINNED` (GREEN, not SEALED) |

## Offline story (what makes zero-network `./x.py build` work)

Offline is **structural**, not a flag:
1. **crates** — the source ships `.cargo/config.toml` redirecting `[source.crates-io]` to a bundled
   `vendor/`; cargo fails **closed** on a miss. `CARGO_NET_OFFLINE=true` is belt-and-braces.
2. **stage0 download** — neutralised by the `[build] rustc/cargo` pins above.
3. **LLVM download/build** — neutralised by external `llvm-config = /usr/bin/llvm-config` +
   `[llvm] link-shared` (packages/llvm 21.1.8; rustc 1.91.1 targets LLVM 21).
4. **git** — a fail-shut stub (P0b) allows ONLY local probes
   (`rev-parse HEAD|--git-dir|--show-toplevel`, `--version`) that vendored `build.rs`
   (wasm-bindgen-shared, cranelift-codegen) make from a `.git`-less tarball; every network verb
   (clone/fetch/pull/remote/ls-remote/**submodule**) is a hard tripwire.
5. **vendored -sys submodules (P0c — the fix a first draft omitted)** — curl-sys / libssh2-sys
   `build.rs` otherwise take an unconditional `git submodule update --init` branch when the shipped
   tarball has no `.git`; that branch hits the git stub **hours** into the build. P0c drops an empty
   `.git` marker into each shipped `vendor/curl-sys-*/curl` and `vendor/libssh2-sys-*/libssh2` so
   the crate compiles its bundled sources instead. Checksum-safe (unlisted extra file is invisible
   to `DirectorySource::verify`; mrustc build.sh:333-337). Version-agnostic by glob because 1.91.1's
   `-sys` versions differ from 1.90.0's and this recipe cannot read the tarball ahead of the build.

## Corrections applied vs the first authored draft

The first authored `packages/rustc-1.91.1/build.sh` was verified-good on stage0-wiring, install
layout, and gate non-vacuity, but adversarial review found three gaps — all fixed here:

1. **[LOAD-BEARING] curl-sys/libssh2-sys submodule markers** — the mrustc offline fix is TWO parts
   (git stub **plus** `.git` markers); the draft shipped only the stub, so curl-sys (no env
   override) would hit `git submodule update --init` hours in. Added **P0c** (version-agnostic
   glob + populated-dir guard + pkg-config diagnostic).
2. **STAGE0_PREFIX generalisation** — the draft hardcoded `/usr/lib/mrustc-rust-${STAGE0_VERSION}`,
   which is correct only for RUNG 1. Now derived by `case`: `mrustc-rust-` for `1.90.0`, `rustc-`
   for every later rung — so rungs 3+ change ONLY `VERSION`/`STAGE0_VERSION`.
3. **Relocatability tripwire** — P4 swept for the source dir (`${BUILDROOT}`) only. Added a second
   sweep for the **DESTDIR staging prefix** (`${OUTPUT_DIR}`): a staging path baked into a TEXT
   file is a real relocation defect that would break the next rung's stage0. Loud, non-fatal
   (never false-fail a 20h build over a possible debuginfo edge).

## Functional gate (why green means something)

A `--version` gate is BANNED (the R5 scar). GATE-1 (`grep 1.91.1`) is a cheap anti-ambient identity
check only. The functional gates all run the INSTALLED binaries from `${OUTPUT_DIR}` after install:
- **GATE-3** compiles AND RUNS ten independent std constructs (iterators/heap, fmt/parse,
  BTree/HashMap, **cross-crate vtable dispatch** into GATE-2's rlib, generics/FnMut, `?`/Option,
  `catch_unwind` unwinding, checked/wrapping overflow, f64 round-trip, threads+`Arc<Mutex>`); the
  exit code is their **computed sum 42**, never a literal, each with a distinct 111-120 code that
  NAMES a miscompile.
- **GATE-4 / GATE-5** are the highest-value for a chain rung: a proc-macro built as a **dylib,
  dlopen'd, expanded, RUN** (42), and **cargo driving** a proc-macro + `#[derive]` build that RUNS
  (42). Rung 3's x.py is cargo-driven and derive-saturated — a rustc that passes only GATE-3 but
  cannot dlopen a proc-macro or be cargo-driven would fail ~hours into rung 3 and be misdiagnosed.

## ⭐ Parameterisation for the 3 later rungs

To author rungs 3/4/5, **copy this directory verbatim** and change only the following. Nothing in
the x.py core, the P0b/P0c offline harness, the bootstrap.toml heredoc, or the six gates changes.
The gate `.rs` files and `.answers` slot are byte-identical copies (only the `.answers` filename
and the two pin paths carry the version).

**In `build.sh` — change ONLY two lines** (`STAGE0_PREFIX` derives itself from `STAGE0_VERSION`):

| rung | `VERSION=` | `STAGE0_VERSION=` | stage0 prefix (auto-derived) |
|---|---|---|---|
| 3 | `1.92.0` | `1.91.1` | `/usr/lib/rustc-1.91.1` |
| 4 | `1.93.1` | `1.92.0` | `/usr/lib/rustc-1.92.0` |
| 5 | `1.94.0` ⚠ | `1.93.1` | `/usr/lib/rustc-1.93.1` |

**In `build.ncl` — four deltas:**

| field | rung 3 | rung 4 | rung 5 |
|---|---|---|---|
| `let version` | `1.92.0` | `1.93.1` | `1.94.0` ⚠ |
| `let stage0_version` | `1.91.1` | `1.92.0` | `1.93.1` |
| stage0 import + dep | `import "../rustc-1.91.1/build.ncl"` → dep `rustc-1-91-1` | `../rustc-1.92.0` → `rustc-1-92-0` | `../rustc-1.93.1` → `rustc-1-93-1` |
| Source `sha256` | 1.92.0-src.tar.xz sha | 1.93.1-src.tar.xz sha | 1.94.0-src.tar.xz sha |

Everything else in `build.ncl` interpolates off `%{version}` (Source URL/strip_prefix, install
prefix, output glob) or is identical (the whole dep set, no `needs`, attrs).

**Rename** `rustc-1.91.1.answers` → `rustc-1.9x.y.answers` and update its two pin paths to
`usr/lib/rustc-<v>/bin/{rustc,cargo}`.

**Rung-2-only specifics that self-resolve for rungs 3+** (no code edit needed): RUNG 1's stage0
`bin/rustc` is a POSIX-sh wrapper reporting `1.90.0-stable-mrustc`; rungs 3+ consume a real-ELF
rustc reporting a clean `1.9x.y`. The substring version check and `--print sysroot` assert both
work for wrapper and ELF, so the version-string-skew and wrapper-relocation risks exist ONLY at
this rung.

## Staging (what to mirror)

| source | status |
|---|---|
| `gs://minimal-staging-archives/rustc-1.91.1-src.tar.xz` | **STAGED** (sha256 `66401bb8…3dbab`, task-provided; verified by the fetcher's re-hash at stage time) |
| `rustc-1.92.0-src.tar.xz` | STAGED — obtain sha from the fetcher's re-hash before authoring rung 3 |
| `rustc-1.93.1-src.tar.xz` | STAGED — obtain sha before rung 4 |
| `rustc-1.94.0-src.tar.xz` | **STAGED** — matches 1.95.0's `src/stage0` pin (recommended endpoint) |
| `rustc-1.94.1-src.tar.xz` | **NOT STAGED** — the version the task named for the final rung |

### ⚠ ENDPOINT DECISION (blocks rung 5 only; does NOT affect this rung)

The task named **1.94.1** as the final rung because that is the exact version of the seeds
`packages/rust` consumes today (`seed-rustc-1.94.1` / `seed-cargo-1.94.1`). But measured:
- only **1.94.0** is staged (not 1.94.1), and
- `packages/rust/build.ncl` records that rust 1.95.0's `src/stage0` **pins 1.94.0**.

**Recommendation:** build rung 5 as **1.94.0** (staged AND pin-matching; 1.95.0 accepts any 1.94.x
stage0) and repoint `packages/rust`'s `[build] rustc/cargo` at `/usr/lib/rustc-1.94.0` — this
deletes the seed tarballs with **no extra staging step**.
**Alternative:** stage `rustc-1.94.1-src.tar.xz` to `gs://minimal-staging-archives` and build 1.94.1
to match the current seeds exactly. Decide before authoring rung 5.

Also verify each later rung's `src/stage0` pin (stream-read it) before firing: measured only that
1.91.1 pins 1.90.0. The N→N-1 invariant makes 1.92.0→1.91.x etc. near-certain, and a wrong pairing
fails fast (seconds), not costly.

## What green proves — and what it does NOT

**Proves:** an attested rustc **1.91.1** exists, built in Confidential Space by our attested rustc
1.90.0 via standard x.py, fully offline, and functionally validated (compiles+runs std, proc-macros
via dlopen, and is cargo-driveable — the exact surface rung 3 needs).

**Does NOT prove:**
- **Not the final rust.** Three more rungs (1.92.0 → 1.93.1 → 1.94.x) are needed before
  `packages/rust`'s seed tarballs can be deleted (issue #17 closes then, not here).
- **Not byte-SEALED.** Ships `# UNPINNED`; the anchor `packages/mrustc` is itself UNPINNED. GREEN ≠
  SEALED. (Sealing `packages/mrustc` first — 2 builds — benefits every rung.)
- **Not hex0-rooted.** The chain root is mrustc (built by `apt g++` on an unattested VM). This rung
  makes the hops attested-in-CS; it moves nothing about that boundary. The C/C++ toolchain building
  this rustc is CS-attested (clang/LLVM from packages/llvm) but likewise not hex0-rooted — a policy
  choice toward the proven/cheap path (see risks).
- **Not yet built end-to-end in CS.** Validated for `sh -n`, `nickel format` (parses clean), and the
  sed/heredoc mechanics only. The strict-offline `./x.py build` path runs for the FIRST time here;
  treat the first CS run as diagnostic — the P0b/P0c tripwires NAME the offending argv/path.

## Risks (fire-order)

1. **[FAST-FAIL] stage0 version-string skew** — RUNG 1 reports `1.90.0-stable-mrustc`, not bare
   `1.90.0`. x.py's own `check_stage0_version` runs SECONDS in and parses `build.rustc --version`.
   An explicit `build.rustc` is normally trusted and a semver prerelease suffix normally ignored,
   but this is UNVERIFIED against 1.91.1's `src/bootstrap` (could not read it without the 270MB
   tarball). If it trips: rebuild RUNG 1 with `CFG_VERSION=1.90.0` (drop the suffix) or patch the
   check. Fails fast, not a 20h loss.
2. **First strict-offline x.py** — packages/rust runs with `needs internet` as a fallback, so it
   never proved x.py is network-free. If any vendored `build.rs` or x.py step attempts a fetch not
   covered by (stage0 pin + vendor redirect + external llvm-config + P0c markers), it fails-shut
   hours in; the tripwires NAME the argv but iteration is multi-hour.
3. **LLVM 21 max-compat per rung** — build.sh asserts `llvm-config` is 21.x. High confidence for
   1.91.1 (rust 1.95.0, same LLVM-21 era, builds against the same config), but confirm 1.92.0/
   1.93.1/1.94.0 also target LLVM ≤21; else bump packages/llvm or build bundled LLVM (~40x).
4. **`change-id = "ignore"`** — assumed accepted by 1.91.1's parser (task cited
   bootstrap.example.toml). If rejected, delete the line (bootstrap warns and proceeds).
5. **Source sha unverified** — the 1.91.1 sha is task-provided (GCS stores only crc32c/md5);
   verified by the fetcher's re-hash at stage time. build.sh compensates with a STRONGER identity
   check (`src/version==1.91.1` AND `src/stage0` pins `compiler_version==1.90.0`).
6. **Naming** — installs to `/usr/lib/rustc-1.91.1` (plain versioned), NOT the task-suggested
   `rustc-bedrock-1.91.1`. Deliberate: this chain is mrustc-rooted, not hex0-bedrock-rooted, so
   `bedrock` would overstate provenance. If the project wants naming consistency with
   gcc-bedrock/glibc-bedrock, `s/rustc-/rustc-bedrock-/` uniformly across all rungs (the next rung
   consumes by absolute path regardless).
