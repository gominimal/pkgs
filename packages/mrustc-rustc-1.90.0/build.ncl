let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# mrustc-rustc-1.90.0 — RUNG 1 of 5 on the road to deleting packages/rust's unattested seeds.
#
# Today:   apt g++ (unattested VM) -> mrustc -> rustc 1.90 -> ... -> 1.94.1 SEED TARBALLS
#          -> [CS, attested] rust 1.95.0
# Target:  hex0 -> ... -> B5 g++ -> [packages/mrustc, SIGNED] -> THIS RUNG -> 1.91 -> 1.92
#          -> 1.93 -> 1.94 -> rust 1.95.0, with the seed tarballs DELETED.
#
# This rung produces an mrustc-rooted rustc 1.90.0 + cargo + libstd, installed as a private
# versioned prefix (usr/lib/mrustc-rust-1.90.0) so it does NOT collide with packages/rust in a
# shared rootfs.  Rung 2 consumes that prefix as its stage0.
#
# ── ⭐ THE SEAM: HYBRID-CONSUMER (measured, not argued) ───────────────────────────────────────
# A prior analysis claimed splitting mrustc from rustc-1.90.0 is a FALSE SEAM. That claim is
# REFUTED on both of its load-bearing points, at the pinned commit 2d14b09:
#
#   1. "output-1.90.0/*.rlib are inherited from the mrustc package."  FALSE.  minicargo.mk:73
#      sets USE_MERGED_BUILD=1 and the 1.90.0 `else` branch at :89-93 does NOT reset it (only
#      the 1.19/1.29/1.39 branches at :76/:84/:88 do), so :235 selects :251-253, which BUILDS
#      the rlibs IN THIS RUNG from $(RUSTCSRC)mrustc-stdlib/Cargo.toml synthesized at :236-250.
#   2. "VENDOR_DIR is an mrustc-tree dependency."  FALSE.  minicargo.mk:98 RUSTCSRC :=
#      rustc-$(RUSTC_VERSION)-src/ and :106 VENDOR_DIR := $(RUSTCSRC)vendor — it is inside the
#      rustc tarball THIS rung already owns.
#
# The deciding lines are minicargo.mk:39 `MRUSTC ?= bin/mrustc$(EXESUF)` and :41 `MINICARGO ?=
# bin/minicargo$(EXESUF)`.  Both are conditional; :282 `$(OUTDIR)rustc: $(MRUSTC) $(MINICARGO)
# LIBS $(LLVM_CONFIG)` lists them as ORDINARY FILE prerequisites.  Point them at the installed
# usr/bin paths and they are existing files with no rule — up to date — so the .PHONY
# self-rebuild rules at :195-198 and :206-208 (which name the LITERAL string `bin/mrustc`) are
# never referenced.  mrustc is NOT rebuilt here.
#
# ── ⚠ THE SHARP EDGE NOBODY HAD CHECKED ──────────────────────────────────────────────────────
# `$(MRUSTC)` does NOT select the compiler that actually runs.  Measured: it appears in exactly
# ONE recipe line in the whole of minicargo.mk (:344, the hello-world test target, which this
# rung never builds).  On the LIBS/rustc/cargo path it is prerequisite-ONLY.  minicargo picks
# mrustc ITSELF — os.cpp:419 honours $MRUSTC_PATH, else :436 readlinks /proc/self/exe and :468
# takes `mrustc` as its own SIBLING.  So `MRUSTC=` and `MINICARGO=` can silently DISAGREE.
# build.sh therefore exports MRUSTC_PATH explicitly AND asserts the consumed binary's identity
# via `mrustc -vV` (src/main.cpp:1015 prints commit-hash).  That assert is load-bearing, not
# decorative — it is the ONLY thing pinning compiler identity on the hot path.
#
# ── WHY HYBRID AND NOT COMBINED (the packages/stage0-gmp-mpfr-mpc precedent does not transfer) ─
# gmp-mpfr-mpc are combined because of CONFIGURE-TIME coupling.  Here the coupling is nine
# static text files.  Reasons to consume rather than rebuild:
#   (a) Iteration economy.  This rung will not go green on attempt 1.  Rebuilding ~130k lines of
#       already-proven-and-SIGNED C++ on every iteration of unproven work is backwards.
#   (b) It makes packages/mrustc LOAD-BEARING.  A signed package nothing depends on is not a
#       rung — nothing stands on it.
#   (c) packages/mrustc/build.ncl:20-24 names this rung `packages/mrustc-rustc-1.90.0` verbatim
#       and records the split as deliberate.
#   (d) It DELETES packages/mrustc/build.sh's entire P2 determinism phase (:176-216 + :248-264),
#       which exists only to make `make -f Makefile all` reproducible.  No `make all`, no
#       referent.
# What hybrid gives up — a cross-build byte-identity check on mrustc — belongs in
# packages/mrustc's own self-arming mrustc.answers, not smuggled into a 20-hour rung.
#
# ── BUT THE TREE IS STILL MANDATORY AS DATA ───────────────────────────────────────────────────
# packages/mrustc installs ONLY the two binaries (build.sh:267-269) + the patch script (:273)
# + BUILDINFO (:277).  None of the tree data.  This rung re-unpacks the SAME sha-pinned
# mrustc-0.12.0.tar and uses it as inert DATA — `make -f Makefile all` is NEVER run.  Required
# (all verified present at 2d14b09):
#     minicargo.mk                          the driver
#     rust-version                          minicargo.mk:16 $(shell cat rust-version) = 1.29.0
#     rustc-1.90.0-src.patch                minicargo.mk:228-229
#     rustc-1.90.0-overrides.toml           minicargo.mk:107 --manifest-overrides (CWD-relative)
#     script-overrides/stable-1.90.0-linux/ minicargo.mk:169 OVERRIDE_DIR, used at :252
#     lib/libproc_macro/                    minicargo.mk:253 — mrustc's OWN crate, ABSENT from
#                                           the rustc tarball
#     run_rustc/{Makefile,rustc_proxy.sh}   stages 1-4
#     samples/hello.rs                      run_rustc/Makefile:72,259
#
# ── SCOPE: run_rustc IS IN (this is an engineering JUDGEMENT, not a file:line proof) ──────────
# The rung runs LIBS -> output-1.90.0/rustc -> output-1.90.0/cargo -> run_rustc stages 1-4.
# Three reasons, the first two measured:
#   1. archive-zerolen-skip.sh's ONLY execution point is run_rustc/Makefile:162
#      (MRUSTC_PATH=$(BINDIR_S)rustc $(MINICARGO) ... sysroot).  ArArchiveBuilder is RUSTC's own
#      Rust code; minicargo.mk never RUNS the built rustc, it only builds it.  Descope run_rustc
#      and the landed strand stays inert for a SECOND rung.
#      (NOTE: this also refutes the scoping note that the patch "first bites at the LIBS stage".
#      LIBS at minicargo.mk:252 is minicargo driving *mrustc*, whose backend is C + binutils ar.)
#   2. Splitting at run_rustc strands ~100GB of intermediate tree (LLVM build dir + vendor/ +
#      patched src + output-1.90.0/) across a package boundary, or forces a SECOND full LLVM
#      build.  run_rustc/Makefile:91 and minicargo.mk:150/:282 point at the SAME cmake-built
#      LLVM inside the SAME extracted tree.
#   3. Rung 2 needs dylib std + working proc macros.  run_rustc/Makefile:218 is the ONLY thing
#      that produces dylib std.  Only here can that be proven (GATE-4).
# The cost of this judgement is named in the SCHEDULE blocker in README.md.  Read it BEFORE
# firing: my honest estimate is 16-30h and 120-180GB against a stated ~10h/~80GB budget.
#
# ── ⚠ HONESTY BOUNDARY — DO NOT OVERSTATE THIS RUNG IN ANY WRITEUP ────────────────────────────
#  1. The anchor is ATTESTED but NOT BYTE-SEALED.  packages/mrustc ships `# UNPINNED`
#     mrustc.answers, and B5/R12 both ship comment-only `# UNPINNED` stage0.answers.  This rung
#     inherits "green", NOT "sealed".  Its strongest in-recipe assert on its own most critical
#     input is a commit STRING the binary prints ABOUT ITSELF (`mrustc -vV`) — a self-assertion.
#     THE FIX IS CHEAP AND INDEPENDENT: run packages/mrustc twice and populate mrustc.answers.
#     That converts the anchor from self-asserted to sealed and benefits every future consumer,
#     for ~2 mrustc builds instead of paying the cost on every iteration of a 20h rung.
#  2. This rung is NOT 2-run byte-identical and is not expected to be.  minicargo.mk:294-303
#     sets no LLVM_APPEND_VC_REV=OFF and no timestamp suppression; the cargo-driven stages have
#     their own metadata-hash surface.  rustc-1.90.0.answers ships UNPINNED and SELF-ARMING.
#  3. The rustc this rung ships is NOT behaviourally identical to upstream 1.90.0.  It carries
#     TWO patches: mrustc's own rustc-1.90.0-src.patch (minicargo.mk:229, 5 hunks) and
#     archive-zerolen-skip.sh.  The latter persists into stage-2/3 because run_rustc/Makefile:207
#     rebuilds rustc from the same patched tree.  Both are semantically null; both are recorded.
#  4. Nothing downstream fail-shuts if this edge regresses — packages/rust's own comment records
#     that assess_dep_chain returns None on a declaredSources hit, so CHAIN_ENFORCE=1 can never
#     flag the seeds.  Proof has to come from THIS recipe's provenance.
#
# ── OFFLINE: STRUCTURALLY GUARANTEED THROUGH `rustc`, MITIGATED BEYOND IT ─────────────────────
# MEASURED against the staged tarball (sha re-derived locally, 279266-entry filelist):
#   * ZERO `git+` sources in all four reachable lockfiles (root 642 pkgs / 517 sourced,
#     library/ 53/35, src/tools/cargo/ 537/512, src/bootstrap/ 130/128).  The single distinct
#     non-path source string across all four is
#     `registry+https://github.com/rust-lang/crates.io-index`.  This REFUTES the standing worry
#     that src/tools/cargo carries git+ deps.
#   * vendor/ holds 1607 crate dirs; vendor coverage of the locks is 100%.
#   * minicargo is STRUCTURALLY incapable of fetching: manifest.h:210 `has_git() { return
#     false; }`; manifest.cpp:984-992 `git`/`branch` keys hit eh.todo(); zero socket/http/popen
#     primitives anywhere in tools/minicargo.  It fails SHUT, it never fetches.
#   * The ONE Makefile-level network call is minicargo.mk:221-224's curl.  Its target has NO
#     prerequisites, so a pre-placed tarball is unconditionally up to date and the recipe cannot
#     fire.  (NOTE: the folklore reason — "make will build a missing prereq that has a rule" —
#     is the WRONG mechanism and would send someone to fix the wrong thing.)
#   * src/llvm-project ships IN the tarball: 82645 entries including llvm/CMakeLists.txt.  The
#     gating blocker "does the tarball contain llvm-project" is RESOLVED: it does.
#
# ── ⚠ THE GIT SURFACE — EXHAUSTIVELY MEASURED OVER ALL 240 VENDORED build.rs ──────────────────
# Nine sites call Command::new("git"), not the six previously believed.  The guards are NOT
# uniform, so the marker set MUST be derived by READING each guard, never by pattern-matching
# on `.git`:
#   FIRES (guard tests a marker the tarball does not ship — 0 `.git` entries in 279266 files):
#     vendor/curl-sys-0.4.82+curl-8.14.1/build.rs:48  `!Path::new("curl/.git").exists()`
#     vendor/curl-sys-0.4.79+curl-8.12.0/build.rs:48  same  (vendored but in NO lock — inert
#                                                      today; marked anyway, it costs nothing)
#     vendor/libssh2-sys-0.3.1/build.rs:35            `!Path::new("libssh2/.git").exists()`
#   DOES NOT FIRE (guard tests real shipped content):
#     vendor/libgit2-sys-0.18.{0,2}/build.rs:66       `!Path::new("libgit2/src").exists()` —
#       libgit2/src ships 404 entries in each.  Adding a `.git` marker here would be cargo-cult.
#   UNGUARDABLE (no marker can suppress these — there is no path to create):
#     vendor/wasm-bindgen-shared-0.2.{100,93,84}/build.rs:10  bare `git rev-parse HEAD`
#     vendor/cranelift-codegen-0.121.0/build.rs:103           bare `git rev-parse HEAD`
# wasm-bindgen-shared 0.2.100 IS in the root AND cargo locks, and js-sys' wasm-bindgen dep is
# UNGATED (js-sys-0.3.77:49) — reachability rests ENTIRELY on minicargo honouring the
# `[target.'cfg(...)']` gating on js-sys' own consumers (uuid-1.17.0:219, iana-time-zone-0.1.63:73,
# getrandom-0.3.3:87, web-time-1.1.0:84).  minicargo DOES honour it: manifest.cpp:1083 calls
# Cfg_Check per target group (:710 is commented out; :1083 is the live one).  So it should be
# unreachable — but "should" is not evidence, and a wrong guess costs 15h.
# build.sh therefore allows EXACTLY `git rev-parse HEAD` (a purely local ref lookup with NO
# network semantics, whose failure every caller already handles at `.output().ok()`), logs it,
# and tripwires + fails on ANY other git argv.  That is not a weakening of the network tripwire:
# no network-capable git verb is allowed.  See build.sh P0b.
# ============================================================================================
let mrustc = import "../mrustc/build.ncl" in # ★ THE ANCHOR — usr/bin/{mrustc,minicargo} + the patch script, from the SIGNED rootfs
let gcc-bedrock = import "../gcc-15.2.0-glibc/build.ncl" in # B5: seed-rooted gcc/g++ 15.2.0 + libstdc++ + libatomic
let binutils-bedrock = import "../binutils-2.46-glibc/build.ncl" in # B5-matched as/ld/ar/ranlib/objcopy/strip
let glibc-bedrock = import "../glibc-bedrock-2.42/build.ncl" in # B4: sysroot (headers + crt + libs + co-located UAPI)
let zlib = import "../zlib/build.ncl" in
# --- NEW at this scope, none of these are in packages/mrustc's P0 tool list (build.sh:46) ---
let cmake = import "../cmake/build.ncl" in # minicargo.mk:311 — the LLVM configure. NOTE: cmake imports ../curl, so a REAL curl lands in the rootfs; P0b's stub shadows it by PATH order and build.sh ASSERTS that.
let python = import "../python/build.ncl" in # LLVM's CMakeLists requires Python3 at configure time
let perl = import "../perl/build.ncl" in # openssl-src build.rs, pulled in by minicargo.mk:90 --features vendored-openssl
let patch = import "../patch/build.ncl" in # minicargo.mk:229 `patch -p0` — a missing `patch` is an unnamed failure 3 minutes in
let pkgconf = import "../pkgconf/build.ncl" in # ships usr/bin/pkg-config (pkgconf/build.ncl:30); several vendored -sys build scripts probe it
let gzip = import "../gzip/build.ncl" in # minicargo.mk:226 `tar -xzf` shells out to gzip
# --- carried over from packages/mrustc ---
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let findutils = import "../findutils/build.ncl" in # install-phase build-path sweep
let diffutils = import "../diffutils/build.ncl" in # `patch` hard-uses cmp on some paths
let version = "1.90.0" in
let mrustc_version = "0.12.0" in
let mrustc_commit = "2d14b09a7e75166bec4413f48f61e3b3cd4de8ca" in
{
  name = "mrustc-rustc-1.90.0",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "rustc-1.90.0.answers" } | Local, # byte-seal slot; SELF-ARMS once populated
    { file = "gatelib.rs" } | Local,           # GATE-3a: the rlib crate — forces ArArchiveBuilder to WRITE an archive
    { file = "gate190.rs" } | Local,           # GATE-3b: ten std constructs, computed 42, exit codes 111-120
    { file = "gate_pm.rs" } | Local,           # GATE-4a: the proc-macro crate
    { file = "gate_pm_use.rs" } | Local,       # GATE-4b: its consumer
    {
      # rustc 1.90.0 source.  .tar.gz IS MANDATORY: minicargo.mk:220 hardcodes
      # rustc-$(RUSTC_VERSION)-src.tar.gz and :226 is `tar -xzf`.  Every other rustc source we
      # have staged is .tar.xz and therefore useless here.
      # sha256 + byte count independently re-derived from the bucket object in this workflow.
      url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.gz",
      sha256 = "799a9f9cba4ed5351e071048bcf6b5560755d9009648def33a407dd4961f9b7e",
      extract = false, # build.sh places it at the mrustc TREE ROOT; `make RUSTCSRC` extracts it
    } | Source,
    {
      # The SAME bytes packages/mrustc pins (its build.ncl:136).  Consumed as DATA ONLY.
      # Re-derivable: git archive --format=tar --prefix=mrustc-0.12.0/ %{mrustc_commit}
      url = "gs://minimal-staging-archives/mrustc-%{mrustc_version}.tar",
      sha256 = "1ad6521c90e47754c5e13bd9abd183f4cd953eb9faa8a25e7b104b6ffe701512",
      extract = false,
    } | Source,
    mrustc,
    gcc-bedrock,
    binutils-bedrock,
    glibc-bedrock,
    zlib,
    cmake,
    python,
    perl,
    patch,
    pkgconf,
    gzip,
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
    findutils,
    diffutils,
  ],
  build_args = {
    include version,
    include mrustc_version,
    include mrustc_commit,
  },
  cmd = "./build.sh",
  outputs = {
    # OutputData + allow_executable throughout, NOT OutputBin: these link against the B4 sysroot
    # loader at a non-standard .interp, and bin/rustc is a SHELL SCRIPT wrapper
    # (run_rustc/Makefile:227) which the interpreter checker would reject.  Precedent:
    # packages/mrustc/build.ncl:156-159 and binutils-2.46-glibc.
    #
    # Private versioned prefix so this does NOT collide with packages/rust's usr/bin/rustc.
    # NOTE on glob semantics (checked against binutils-2.46-glibc/build.ncl:88 and
    # gcc-15.2.0-glibc/build.ncl:97): `*` is non-recursive, `**` is recursive.
    # NOTE: an EMPTY glob FAILS enumeration ("output globs did not match any files"), see
    # binutils-2.46-glibc/build.ncl:93-94.  `dylibs` is the one at risk — it is non-empty only
    # if run_rustc/Makefile:218 (`cp $(LIBDIR_2)*.$(DYLIB_EXT) $(PREFIX)lib`) really produced
    # dylib std.  That is exactly what GATE-4 proves, so a red `dylibs` glob and a red GATE-4
    # mean the same thing.
    bins = { glob = "usr/lib/mrustc-rust-1.90.0/bin/*", allow_executable = true } | OutputData,
    dylibs = { glob = "usr/lib/mrustc-rust-1.90.0/lib/*.so*", allow_executable = true } | OutputData,
    rustlib = { glob = "usr/lib/mrustc-rust-1.90.0/lib/rustlib/**", allow_executable = true } | OutputData,
    buildinfo = { glob = "usr/share/mrustc-rust-1.90.0/BUILDINFO" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rust-lang",
        repo = "rust",
      },
      # A GUESS, not a measurement.  LLVM via cmake + LIBS + rustc lowered to C by mrustc +
      # cargo + four run_rustc stages.  See the SCHEDULE blocker in README.md — this number is
      # the single most likely thing in this file to be wrong.
      build_cost_multiple = 40,
    } | Attrs,
} | BuildSpec
