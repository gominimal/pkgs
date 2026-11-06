let { Attrs, BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let lean = import "../lean/build.ncl" in
let { target, .. } = import "config.ncl" in

# Mathlib's release tag for the lean we ship (leanprover-community/mathlib4
# tag v4.35.0 = 56a005855ea17e0b0958f73ec801ae140b0a1679). `mathlib` carries
# the same version and its build.sh refuses a mismatch.
let version = "4.35.0" in
# How many `lean` processes lake runs at once (each also gets this as its own
# thread cap), per builder arch: the target for the build-bot machines. It is
# also build_cost_multiple below, so the orchestrator reserves what we use.
# It is in the spec hash but not in the bytes: 4, 6 and 8 gave identical
# output trees, as did the build-bot's 32/16 (pkgs#1244).
#
# A smaller box (a local `min package build` on a laptop) cannot lower this
# without a new spec hash, so build.sh lowers the count it actually runs to
# fit the box: min(this, CPUs, free memory / 1.5 GiB). A 16 GiB laptop gets
# ~8 jobs instead of 16. Same bytes, same spec hash.
#
# Sized by memory, the only resource it could exhaust: the res-server
# sandbox sets no memory.max and no CPU quota (only a cpu.weight that grows
# with build_cost_multiple). Peak RSS of one `lean` measured at 2.8 GiB
# (AlgebraicGeometry/ProjectiveSpectrum/Functor), median ~0.9 GiB. Even if
# every job peaked at once: 32 x 2.8 = ~90 GiB of the amd64 builder's
# 360 GiB (c4-standard-96), 16 x 2.8 = ~45 GiB of the arm64 builder's
# 192 GiB (c4a-standard-48), both under half of the shared machine.
#
# arm64 is 16, not more, because build_cost_multiple is the same number and
# the arm64 res-server's per-request pool is 23 slots: 24 (capped to 23) would
# reserve the whole pool and hold every other arm64 build until this one
# finishes.
#
# Wall time has a floor of its own: the longest import chain through Mathlib
# is ~5.4 min of compile time (local per-module timings), so past ~32 jobs
# extra threads buy little.
let threads =
  match {
    { arch = 'Amd64, .. } => 32,
    { arch = 'Arm64, .. } => 16,
  } target
in
{
  name = "mathlib-oleans",
  # The COMPILE half of `mathlib`: all of Mathlib v4.35.0 (8,625 modules,
  # Mathlib.lean + Mathlib/**) and the Lake packages it requires, compiled
  # from source, offline, for the lean we ship, plus the licences and
  # third-party notices for that code. LEAN_PATH and MANIFEST live in the
  # thin `mathlib` package, which depends on this one: a recipe edit there
  # rebuilds `mathlib` in seconds instead of this ~35 min compile
  # (pkgs#1244). Install `mathlib` for LEAN_PATH; this package alone is
  # complete for redistribution.
  #
  # Licences: ProofWidgets' oleans embed its widget JS (npm code, a Graphviz
  # WebAssembly under EPL-2.0/CPL-1.0, a Rust WebAssembly), so this package
  # ships the same licence texts, notices and EPL/CPL source offer as
  # `mathlib`, from the same files: packages/mathlib/notices.ncl lists them
  # and its install-licences.sh installs them in both. A notice edit
  # therefore rebuilds this package too; notices change only on a
  # ProofWidgets bump or a correction, and a bump recompiles this anyway.
  #
  # The inputs are the nine sha256-pinned Sources in sources.ncl, the
  # notices from packages/mathlib/notices.ncl, `lean`, and `base`; the build
  # arg is the thread count. `mathlib` imports the same two files, so the
  # two packages cannot drift.
  #
  # FROM SOURCE, OFFLINE. No `lake exe cache get`: Mathlib's Azure cache is an
  # unverified prebuilt (its files are keyed by a hash of their INPUTS, nothing
  # checks the bytes that come back). This package has no `needs`.
  #
  # Offline-lake mechanism adopted from nixpkgs
  # `pkgs/build-support/lake` (MIT, © Eelco Dolstra and the Nixpkgs/NixOS
  # contributors): each Lake dependency is a pinned source placed under
  # `.lake/packages/<name>`, `.lake/package-overrides.json` points lake at
  # those directories, `LAKE_NO_CACHE=1` + an empty `RESERVOIR_API_URL` keep
  # it from reaching out.

  #
  # `lean`, `mathlib-oleans`, `mathlib` and `aeneas-latest` move TOGETHER: a
  # Mathlib tag supports exactly one Lean (`fixedToolchain := true` in its
  # lakefile); build.sh refuses a mismatch. Bump this with lean.
  #
  # One prebuilt remains inside the pinned sources: ProofWidgets commits its
  # compiled infoview JavaScript (widget/js/*.js, bundled from npm) at each
  # release, and its oleans embed those strings via `include_str`. Mathlib
  # requires ProofWidgets with `errorOnBuild`, and there is no node/npm here,
  # so if lake ever decided the JS needed rebuilding the build fails rather
  # than fetching. build.sh records the hash of every bundle it compiled in,
  # and `mathlib` refuses to package notices checked against other bundles.
  build_deps =
    [
      { file = "build.sh" } | Local,
    ]
    # The licence installer and third-party notices (shared with `mathlib`).
    @ (import "../mathlib/notices.ncl")
    # The nine pinned sources (sources.ncl; `mathlib` imports the same file).
    @ (import "sources.ncl")
    @ [
      base,
      # lean is a runtime dep (below), so it is in this build too.
    ],

  cmd = "./build.sh",
  build_args = {
    include version,
    lean_num_threads = std.to_string threads,
  },

  # Oleans per Lake package, dot-free so the globs see them,
  # `usr/lib/lean/mathlib/<name>/lib/…`. A consumer runs plain `lean` with
  #   LEAN_PATH=$(cat /usr/share/mathlib/LEAN_PATH)
  # (that file is the `mathlib` package's).
  #
  # Its own root, not usr/lib/lean/pkgs (aeneas-latest's): the sandbox
  # resolves a path conflict per file, so if two packages ever installed the
  # same module under one root, a closure holding both could load its .olean
  # from one build and its .olean.server/.olean.private/.ir from the other.
  # A root of its own keeps this tree whole.
  outputs = {
    oleans = { glob = "usr/lib/lean/mathlib/**/*.olean*" } | OutputData,
    # Language-server index; makes `lean --server` (go-to-definition into
    # Mathlib) work. Separate output so a batch consumer can subset it away.
    ileans = { glob = "usr/lib/lean/mathlib/**/*.ilean" } | OutputData,
    # Compiled IR per module: without it lean cannot run an imported module's
    # `initialize` code (pkgs#693 / aeneas-latest).
    ir = { glob = "usr/lib/lean/mathlib/**/*.ir" } | OutputData,
    ir_sig = { glob = "usr/lib/lean/mathlib/**/*.ir.sig" } | OutputData,
    # What this compile was built from (Mathlib's lake-manifest.json, its
    # lean-toolchain, the sha256 of every ProofWidgets widget bundle the
    # oleans embed). `mathlib` checks its own sources against these.
    build_info = { glob = "usr/share/mathlib-oleans/*" } | OutputData,
    # Every upstream LICENSE, the ProofWidgets JS/WebAssembly third-party
    # notices and the EPL/CPL source offer (the same files `mathlib` ships).
    # Required for redistribution.
    licenses = { glob = "usr/share/licenses/mathlib-oleans/**" } | OutputData,
  },

  runtime_deps = [
    lean,
  ],

  attrs =
    {
      upstream_version = version,
      # Same code as `mathlib`, so the same licences: the nine sources are
      # Apache-2.0 (Mathlib, batteries, aesop, Qq, ProofWidgets4,
      # import-graph, LeanSearchClient, plausible) and MIT (lean4-cli), and
      # ProofWidgets' oleans embed its widget JS, whose npm and WebAssembly
      # contents add the rest. See `mathlib`'s build.ncl for the breakdown.
      # The `licenses` output carries the texts and the EPL/CPL source offer.
      license_spdx = "Apache-2.0 AND MIT AND ISC AND BSD-3-Clause AND CC-BY-4.0 AND CC0-1.0 AND Unlicense AND EPL-2.0 AND CPL-1.0 AND Apache-2.0 WITH LLVM-exception",
      # The cache serves this artifact so `mathlib` users skip the compile.
      # It carries its own licences and notices (`licenses` above), so it is
      # complete when installed without `mathlib`.
      redistributable = true,
      source_provenance = {
        category = 'GithubRepo,
        owner = "leanprover-community",
        repo = "mathlib4",
      },
      # A concurrency weight, not a duration: the orchestrator acquires this
      # many build slots (capped at the res-server's per-request pool: 23 on
      # c4a-standard-48, 39 on c4-standard-96), and build.sh runs
      # lean_num_threads lean jobs. Measured at 8 threads on build-bot:
      # 31.3 min amd64, 33.8 min arm64; in a 6-vCPU arm64 min box, 47.6 min
      # at 4 threads and 44.8 at 6.
      build_cost_multiple = threads,
    } | Attrs,

  tests = {
    # The compile alone, without `mathlib`'s LEAN_PATH file: import all of
    # Mathlib from the installed trees.
    imports_mathlib =
      {
        class = 'Standalone,
        test_deps = [base, lean],
        cmds = [
          ["/bin/bash", "-c", "export LEAN_PATH=$(ls -d /usr/lib/lean/mathlib/*/lib | paste -sd:) && printf 'import Mathlib\\nexample (x : Real) (h : 0 <= x) : Real.sqrt (x ^ 2) = x := Real.sqrt_sq h\\n' > /tmp/t.lean && lean /tmp/t.lean 2>&1"],
        ],
      } | Test,
  },
} | BuildSpec
