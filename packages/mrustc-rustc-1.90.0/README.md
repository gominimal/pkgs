# packages/mrustc-rustc-1.90.0 — rung 1 of 5

Builds **rustc 1.90.0 + cargo + libstd** using the **signed `packages/mrustc`**, on the
seed-rooted ladder, offline, in Confidential Space. First of five rungs
(1.90.0 → 1.91.1 → 1.92.0 → 1.93.1 → 1.94.1) that would let us delete `packages/rust`'s
unattested seed tarballs — today those are produced on a plain GCE VM by `apt-get install g++`.

Installs to a **private versioned prefix** `usr/lib/mrustc-rust-1.90.0/` so it does not collide
with `packages/rust`'s `usr/bin/rustc`. Rung 2 consumes that prefix as its stage0.

---

## 1. SEAM VERDICT: **HYBRID-CONSUMER** — the "false seam" claim is refuted

**Consume** the signed `usr/bin/{mrustc,minicargo}`. **Re-unpack** the same sha-pinned
`mrustc-0.12.0.tar` as inert **DATA**. **Never** run `make -f Makefile all`.

The deciding lines, all read at the pinned `2d14b09` (not the `ce622338` working tree):

| Fact | Evidence |
|---|---|
| `MRUSTC`/`MINICARGO` are overridable | `minicargo.mk:39,41` — `?=` conditional assignment |
| They are ordinary **file** prerequisites | `minicargo.mk:282` `$(OUTDIR)rustc: $(MRUSTC) $(MINICARGO) LIBS $(LLVM_CONFIG)` |
| The self-rebuild rules become unreferenced | `minicargo.mk:195-198`, `:206-208` name the **literal** string `bin/mrustc` |
| mrustc is fully relocatable | `grep -c 'proc/self/exe' src/main.cpp` = **0**; target spec compiled in (`target.cpp:428`) |
| minicargo finds mrustc as a sibling | `os.cpp:419` `MRUSTC_PATH`, else `:436` readlink, `:468` sibling |

**The prior analysis was wrong on both load-bearing points:**

1. *"`output-1.90.0/*.rlib` are inherited from the mrustc package."* **False.** `minicargo.mk:73`
   sets `USE_MERGED_BUILD=1`; the 1.90.0 `else` branch at `:89-93` does **not** reset it (only
   `:76/:84/:88` do, for 1.19/1.29/1.39). So `:235` selects `:251-253`, which builds the rlibs
   **in this rung** from `$(RUSTCSRC)mrustc-stdlib/Cargo.toml` synthesized at `:236-250`.
2. *"`VENDOR_DIR` is an mrustc-tree dependency."* **False.** `minicargo.mk:98` + `:106` →
   `rustc-1.90.0-src/vendor`, inside the tarball this rung already owns.

`packages/stage0-gmp-mpfr-mpc` does not transfer: that combination exists because of
**configure-time** coupling. Here the coupling is **nine static text files**.

### ⚠ The sharp edge nobody had checked

**`$(MRUSTC)` does not select the compiler that actually runs.** Measured: it appears in exactly
**one** recipe line in all of `minicargo.mk` — `:344`, the hello-world test target this rung
never builds. On the LIBS/rustc/cargo path it is **prerequisite-only**; minicargo picks mrustc
itself via `os.cpp:419/:436/:468`. So `MRUSTC=` and `MINICARGO=` can silently disagree.

`build.sh` therefore exports `MRUSTC_PATH` **and** asserts `mrustc -vV` reports commit
`2d14b09…` (`src/main.cpp:1015`). That assert is **load-bearing** — it is the only thing pinning
compiler identity on the hot path.

---

## 2. FILES WRITTEN

| File | Role |
|---|---|
| `build.ncl` | Recipe. 2 Sources, 20 package deps, private-prefix outputs. |
| `build.sh` | 9 phases, P0 → P8. |
| `gatelib.rs` | GATE-2's rlib crate — forces `ArArchiveBuilder` to **write** an archive. |
| `gate190.rs` | GATE-3 — ten std constructs, computed 42, exit codes 111-120. |
| `gate_pm.rs` | GATE-4a — the proc-macro crate. |
| `gate_pm_use.rs` | GATE-4b — its consumer. |
| `rustc-1.90.0.answers` | Self-arming byte-seal slot. Ships `# UNPINNED`. |

**The gate programs were compiled and executed** (rustc 1.97.1 locally), and non-vacuity was
verified **causally**, not asserted:

| Build | Exit | Meaning |
|---|---|---|
| clean | **42** | passes |
| all guards rewritten to `if false` | **42** | the *sum* is the gate; guards are diagnosis only |
| wrong `c4` + its guard dead | **43** | a miscompile cannot pass vacuously |

That middle row caught a **real bug in my own first draft**: `h.join()` was a side-effecting call
embedded in a guard condition, so neutering the guard skipped the join and raced (scored 40).
Fixed and commented in `gate190.rs`. Worth generalising: **never put a side-effecting call inside
a gate's guard condition** — it makes the accumulated value depend on the guard executing, which
is exactly what the guard is supposed to be testing.

---

## 3. STAGING COMMANDS

**Nothing to stage. Both Sources are already in the bucket and I re-derived both shas locally
in this workflow** (streamed the object, recomputed, cross-checked byte counts):

| Source | sha256 | bytes |
|---|---|---|
| `gs://minimal-staging-archives/rustc-1.90.0-src.tar.gz` | `799a9f9cba4ed5351e071048bcf6b5560755d9009648def33a407dd4961f9b7e` | 602086131 |
| `gs://minimal-staging-archives/mrustc-0.12.0.tar` | `1ad6521c90e47754c5e13bd9abd183f4cd953eb9faa8a25e7b104b6ffe701512` | 8304640 |

`.tar.gz` is **mandatory** — `minicargo.mk:220` hardcodes `rustc-$(RUSTC_VERSION)-src.tar.gz`
and `:226` is `tar -xzf`. Every other rustc source we have staged is `.tar.xz` and useless here.

Re-derive the mrustc tarball:
```
git archive --format=tar --prefix=mrustc-0.12.0/ 2d14b09a7e75166bec4413f48f61e3b3cd4de8ca
```

**No third Source is needed — the gating blocker is RESOLVED.** `src/llvm-project/` **is** in the
tarball: **82645 entries**, including `llvm/CMakeLists.txt`. Every native sub-source is populated
in-tarball too (curl 790, libssh2 482, libgit2/src 404, openssl, zlib). All 20 package deps exist
in the tree, including the ones new at this scope (`cmake`, `python`, `perl`, `patch`, `pkgconf`,
`gzip`).

> Correction to a prior note: **`pkg-config` is available** — `packages/pkgconf/build.ncl:30`
> ships `usr/bin/pkg-config`. The earlier claim that it is absent came from looking for a
> package *named* `pkg-config`.

---

## 4. WHAT GREEN WOULD PROVE / NOT PROVE

### Would prove
- A rustc 1.90.0 whose **C++ host compiler edge is our seed-rooted g++ 15.2.0 (B5)**, not apt's,
  built offline in CS from sha-pinned sources.
- **LLVM was built by our g++** — GATE-6 greps `cxxwrap.log` for `llvm-project`. This plugs
  `minicargo.mk:301`, where `CMAKE_CXX_COMPILER="$(CXX)"` reads a *make builtin* and fails
  **silently** when wrong. `packages/mrustc` never covered this.
- **The rustc genuinely works**: ten std constructs compiled *and executed* with a computed
  result (GATE-3), an rlib written *and read back across a crate boundary* (GATE-2 + c4),
  **proc macros built as a dylib, dlopen'd, expanded and run** (GATE-4), and cargo driving a real
  two-crate build (GATE-5).
- **`archive-zerolen-skip.sh` finally executes.** Its only execution point is
  `run_rustc/Makefile:162`. This ends a strand that has been inert since it was landed.

### Would NOT prove
- **Not sealed.** Both this rung and its anchor ship `# UNPINNED` answers. The in-recipe assert
  on `packages/mrustc` is a commit *string the binary prints about itself* — a self-assertion.
  Green here means **green, not sealed**.
- **Not byte-reproducible**, and not expected to be on attempt 1.
- **Not upstream-identical.** The shipped rustc carries two patches
  (`rustc-1.90.0-src.patch`, 5 hunks, `minicargo.mk:229`; and `archive-zerolen-skip.sh`), and the
  latter persists into stage-2/3 because `run_rustc/Makefile:207` rebuilds from the same tree.
  Both semantically null; both recorded in BUILDINFO.
- **Does not prove rung 2 will work.** Whether 1.91.1's `x.py` bootstraps from this prefix is
  **unresolved** and is the first thing rung 2 must establish. GATE-4 is the strongest available
  proxy — it is why proc macros are gated here rather than discovered 20h into rung 2.
- **Nothing downstream fail-shuts** if this edge regresses: `assess_dep_chain` returns `None` on a
  `declaredSources` hit, so `CHAIN_ENFORCE=1` can never flag the seeds.

---

## 5. BLOCKERS, ordered

### 🔴 B1 — SCHEDULE AND DISK. Resolve **before** firing; this is the one that can waste ~20h.
The stated budget is **~10h / ~80GB**. My honest estimate is **16-30h and 120-180GB**. Five
serial heavy phases: LLVM via cmake → LIBS → `output-1.90.0/rustc` (mrustc lowers the whole
compiler to C, then gcc compiles it) → `output-1.90.0/cargo` (+ vendored openssl/libgit2/curl) →
run_rustc stages 1-4, whose middle stages are driven by an **unoptimised** mrustc-built rustc
(`run_rustc/Makefile` header: *"mrustc is bad at codegen"*).

Worse: **`minicargo.mk:176-179` declares `$(OUTDIR)rustc`, `$(OUTDIR)cargo`, all four rlibs and
`LIBS` `.PHONY`.** There is **no make-level incremental protection** — a re-run after a mid-build
failure re-enters minicargo for everything. Resume economy rests entirely on minicargo's internal
timestamp check (`build.cpp:749`).

**CHECK THE CS BUILDER'S TIMEOUT AND DISK FIRST.** If the rung cannot fit in one CS build, the
answer is **not** to split at run_rustc (see B2) — it is to raise the timeout.
`attrs.build_cost_multiple = 40` is a guess, not a measurement.

### 🟠 B2 — run_rustc is in scope, and that is an engineering *judgement*, not a proof
Two measured reasons: (a) `archive-zerolen-skip.sh`'s only execution point is
`run_rustc/Makefile:162` — descope it and the landed strand stays inert for a *second* rung;
(b) `run_rustc/Makefile:91` and `minicargo.mk:150/:282` point at the **same** cmake-built LLVM in
the **same** extracted tree, so splitting strands ~100GB across a package boundary or forces a
second full LLVM build. One judgement reason: rung 2 needs dylib std + proc macros, and
`run_rustc/Makefile:218` is the only thing producing dylib std.

This is labelled as judgement in `build.ncl`, deliberately not presented alongside the measured
seam evidence.

### 🟠 B3 — The git surface is larger and less uniform than previously believed
**Exhaustively measured over all 240 vendored `build.rs`: nine sites call `Command::new("git")`,
not six.** The guards are **not uniform**:

| Site | Guard | Fires? |
|---|---|---|
| `curl-sys-0.4.82+curl-8.14.1/build.rs:48` | `curl/.git` | **YES** — marker required |
| `curl-sys-0.4.79+curl-8.12.0/build.rs:48` | `curl/.git` | in **no** lock; marked defensively |
| `libssh2-sys-0.3.1/build.rs:35` | `libssh2/.git` | **YES** — marker required |
| `libgit2-sys-0.18.{0,2}/build.rs:66` | `libgit2/**src**` | **no** — 404 entries ship. A `.git` marker here is cargo-cult. |
| `wasm-bindgen-shared-0.2.{100,93,84}/build.rs:10` | **none** | **unguardable** |
| `cranelift-codegen-0.121.0/build.rs:103` | **none** | **unguardable**; in no lock |

`wasm-bindgen-shared` 0.2.100 **is** in the root and cargo locks, and **js-sys' `wasm-bindgen`
dep is ungated** (`js-sys-0.3.77:49`). Reachability rests entirely on minicargo honouring
`[target.'cfg(…)']` gating on js-sys' consumers — which it does (`manifest.cpp:1083`; note `:710`
is commented out). But "should be unreachable" is not evidence, and a wrong guess costs ~15h.

**Mitigation shipped:** markers for the three guarded sites, **plus** a git stub that permits
**exactly `git rev-parse HEAD`** — a purely local ref lookup with zero network semantics, whose
failure every caller already handles (`.output().ok()`) — and tripwires **every other argv**.
This is not a weakening: no network-capable verb is allowed. Plus `GIT_CEILING_DIRECTORIES`, so
"git fails locally" is a property of the *design*, not of the ambient filesystem.

**Do not derive the marker list by pattern-matching on `.git`.** Derive it by reading each guard.

### 🟡 B4 — LLVM's cmake compiler detection has never run in CS
`minicargo.mk:301` hands cmake our **shell-script wrapper** as `CMAKE_C_COMPILER`/
`CMAKE_CXX_COMPILER`. cmake runs ABI-detection compile+link probes; the wrapper appends `-Wl`
flags on non-`-c` invocations, which should be fine, but this exact combination is untested.
Fallback is plain `gcc`/`g++` with flags baked via `CMAKE_C_FLAGS`/`CMAKE_EXE_LINKER_FLAGS` —
but that **weakens GATE-6(c)**. Worth a 10-minute local container probe before the full run.

Related: `build.sh` uses `-nostdinc`, so LLVM sees only `${SR}/include` + gcc internals. That
should suffice (LLVM needs libc + libstdc++ only, and zlib is `OFF`), but it is untested at this
scale.

### 🟡 B5 — Seal the anchor first. Cheap, independent, and it improves every future consumer.
`packages/mrustc` ships `# UNPINNED` `mrustc.answers`. Run it **twice** and populate it. That
converts this rung's anchor from *self-asserted* to *sealed* for ~2 mrustc builds, instead of
carrying the uncertainty through every iteration of a 20-hour rung. **Do this before B1.**

### 🟡 B6 — Two smaller traps, both handled but worth knowing
- **`run_rustc/Makefile:227`** bakes absolute build-tree paths into the shipped `bin/rustc`
  wrapper (it computes `d=$(dirname $0)` and then *doesn't use it*). P6 regenerates the wrapper
  `$0`-relative and sweeps the whole tree with `grep -F "${BUILDROOT}"`, fail-shut. Same failure
  *class* as the lean stage0 `/proc/<pid>/exe` bug.
- **`run_rustc/Makefile:44-47`** gates version behaviour with a **shell string comparison**
  (`test "$(RUSTC_VERSION)" ">" "1.74"`) and has no `TARGETVER_LEAST_1_90`, so 1.90.0 rides the
  1.74 path — correct today only by lexicographic luck. Harmless for rungs 1.90-1.94; **do not
  let anyone generalise the pattern**.

---

## 6. Corrections to received analysis (measured here)

- **The `.tar.gz` mechanism folklore is wrong.** "Make will build a missing prerequisite that has
  a rule, i.e. fire curl, even if you pre-extract and touch the stamps" — the tarball target
  (`minicargo.mk:221`) has **no prerequisites**, so once the file exists it is unconditionally up
  to date and the curl recipe *cannot* fire. Pre-placement works; the stated reason would send
  someone to fix the wrong thing.
- **`archive-zerolen-skip.sh` does not bite at LIBS.** `minicargo.mk:252` is minicargo driving
  *mrustc*, whose backend is C + binutils `ar`. `ArArchiveBuilder` is *rustc's* Rust code; first
  execution is `run_rustc/Makefile:162`.
- **The script's stated mechanism is imprecise.** `archive.rs:490` is `.map_err(…)?` — an `Err`,
  not an abort. The SIGABRT arrives downstream via `emit_fatal(ArchiveBuildFailure)` → FatalError
  panic → abort without unwinding. **Grep a failing log for `failed to map object file` /
  `ArchiveBuildFailure`, not for a bare SIGABRT.** (GATE-2 hints exactly this.)
- **Zero `git+` sources**, all four lockfiles (642/517, 53/35, 537/512, 130/128); one distinct
  source string: `registry+https://github.com/rust-lang/crates.io-index`. The standing worry that
  `src/tools/cargo` carries git+ deps is **refuted**.
- **`pkg-config` is available** via `packages/pkgconf` (see §3).

## 7. Verified independently in this workflow
`rustc-1.90.0-src.tar.gz` sha256 + byte count re-derived from the local copy · 279266-entry
filelist · `src/llvm-project` presence · all 240 vendored `build.rs` grepped for git · every git
guard read · all four lockfiles counted for `git+` · `minicargo.mk` confirmed byte-identical
between the working tree and `2d14b09` · `archive.rs` needle uniqueness (1, at `:474`) and enum
shape (`:337-340`) · `manifest.h:210` / `manifest.cpp:984-992,1083` · `os.cpp:419/436/468` ·
`main.cpp:969-996,1015` · gate programs compiled, executed, and causally falsified.
