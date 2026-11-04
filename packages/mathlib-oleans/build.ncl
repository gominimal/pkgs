let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let lean = import "../lean/build.ncl" in

# Mathlib's release tag for the lean we ship (leanprover-community/mathlib4
# tag v4.35.0 = 56a005855ea17e0b0958f73ec801ae140b0a1679). `mathlib` carries
# the same version and its build.sh refuses a mismatch.
let version = "4.35.0" in
# How many `lean` processes lake runs at once (each also gets this as its own
# thread cap). A memory decision, not a CPU one; see build.sh step 4. Also the
# build_cost_multiple below, so the orchestrator reserves what we use. It is
# in the spec hash but not in the bytes: 4, 6 and 8 gave identical output
# trees (pkgs#1244). Peak RSS of one `lean` measured at 2.8 GiB
# (AlgebraicGeometry/ProjectiveSpectrum/Functor), median ~0.9 GiB.
let threads = 8 in
{
  name = "mathlib-oleans",
  # The COMPILE half of `mathlib`: all of Mathlib v4.35.0 (8,625 modules,
  # Mathlib.lean + Mathlib/**) and the Lake packages it requires, compiled
  # from source, offline, for the lean we ship. Nothing else. Licences,
  # third-party notices, LEAN_PATH and MANIFEST live in the thin `mathlib`
  # package, which depends on this one: a notice or recipe edit there rebuilds
  # `mathlib` in seconds instead of this ~35 min compile (pkgs#1244). Use
  # `mathlib`, not this package: only `mathlib` carries the notices the
  # redistributed oleans need (ProofWidgets' oleans embed its widget JS).
  #
  # The inputs are exactly the nine sha256-pinned Sources in sources.ncl,
  # `lean`, and `base`; the build arg is the thread count. `mathlib` imports
  # the same sources.ncl, so the two cannot drift.
  #
  # FROM SOURCE, OFFLINE. No `lake exe cache get`: Mathlib's Azure cache is an
  # unverified prebuilt (its files are keyed by a hash of their INPUTS, nothing
  # checks the bytes that come back). This package has no `needs`.
  #
  # Offline-lake mechanism as in aeneas-latest, adopted from nixpkgs
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
    # The nine pinned sources (sources.ncl; `mathlib` imports the same file).
    @ (import "sources.ncl")
    @ [
      base,
      lean,
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
  # Deliberately NOT aeneas-latest's root (usr/lib/lean/pkgs): both packages
  # build mathlib, batteries, aesop, …, and the sandbox resolves a path
  # conflict per file, so a closure holding both could load a module's .olean
  # from one build and its .olean.server/.olean.private/.ir from the other.
  # Disjoint roots keep each package's tree whole.
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
      # contents add the rest. See `mathlib`'s build.ncl for the breakdown;
      # its `licenses` output carries the texts and the EPL/CPL source offer.
      license_spdx = "Apache-2.0 AND MIT AND ISC AND BSD-3-Clause AND CC-BY-4.0 AND CC0-1.0 AND Unlicense AND EPL-2.0 AND CPL-1.0",
      # The cache serves this artifact so `mathlib` users skip the compile.
      # Its notices travel in `mathlib`, which is what users install (this
      # package is its runtime dep); installed on its own, this package
      # carries no licence texts.
      redistributable = true,
      source_provenance = {
        category = 'GithubRepo,
        owner = "leanprover-community",
        repo = "mathlib4",
      },
      # A concurrency weight, not a duration: the orchestrator acquires this
      # many build slots, and build.sh runs lean_num_threads lean jobs.
      # Measured on build-bot (pkgs#1244 at 5f1857d, 8 threads): 28.5 min on
      # c4-standard-96 (amd64), 33.0 min on c4a-standard-48 (arm64). In a
      # 6-vCPU arm64 min box: 47.6 min at 4 threads, 44.8 min at 6.
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
