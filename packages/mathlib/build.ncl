let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let lean = import "../lean/build.ncl" in

# Mathlib's release tag for the lean we ship (leanprover-community/mathlib4
# tag v4.35.0 = 56a005855ea17e0b0958f73ec801ae140b0a1679).
let version = "4.35.0" in
{
  name = "mathlib",
  # ALL of Mathlib, compiled from source for the lean we ship: 8,625 modules
  # (Mathlib.lean + Mathlib/**), plus the Lake packages it requires. This is
  # what `import Mathlib`, Mathematics in Lean and anything touching
  # Real/Analysis/Topology need; `aeneas-latest` ships only the ~1,200-module
  # closure Aeneas imports.
  #
  # FROM SOURCE, OFFLINE. No `lake exe cache get`: Mathlib's Azure cache is an
  # unverified prebuilt (its files are keyed by a hash of their INPUTS, nothing
  # checks the bytes that come back). This package has no `needs`; every input
  # is a sha256-pinned Source below.
  #
  # Offline-lake mechanism as in aeneas-latest, adopted from nixpkgs
  # `pkgs/build-support/lake` (MIT, © Eelco Dolstra and the Nixpkgs/NixOS
  # contributors): each Lake dependency is a pinned source placed under
  # `.lake/packages/<name>`, `.lake/package-overrides.json` points lake at
  # those directories, `LAKE_NO_CACHE=1` + an empty `RESERVOIR_API_URL` keep
  # it from reaching out.
  #
  # The dependency pins are Mathlib v4.35.0's own lake-manifest.json, and they
  # are identical to the ones aeneas-latest vendors, so the sources are the
  # same mirrored tarballs (same sha256) under aeneas-latest/ in staging.
  #
  # `lean`, `mathlib` and `aeneas-latest` move TOGETHER: a Mathlib tag
  # supports exactly one Lean (`fixedToolchain := true` in its lakefile);
  # build.sh refuses a mismatch. Bump this with lean.
  #
  # One prebuilt remains inside the pinned sources: ProofWidgets commits its
  # compiled infoview JavaScript (widget/js/*.js, bundled from npm) at each
  # release, and its oleans embed those strings via `include_str`. Mathlib
  # requires ProofWidgets with `errorOnBuild`, and there is no node/npm here,
  # so if lake ever decided the JS needed rebuilding the build fails rather
  # than fetching. Rebuilding that JS from TypeScript is a follow-up.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/aeneas-latest/mathlib-56a0058.tar.gz",
      sha256 = "45567f6e07607b787026d287c8ec1828f6cabc8debe11a45a521750580e3a0d5",
      extract = true,
    } | Source,
    # leanprover-community/plausible @ dfa4f38190d07c37e315953e08b90fe2d95b3c24 (Mathlib lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/plausible-dfa4f38.tar.gz",
      sha256 = "3f157cbc2450a6d14f32f18c7a1efd12ee8209a335b3c8ea05248eece9beb342",
      extract = true,
    } | Source,
    # leanprover-community/LeanSearchClient @ d6b4c7be5be75ec4917c873ac50c756dc1436372
    {
      url = "gs://minimal-staging-archives/aeneas-latest/LeanSearchClient-d6b4c7b.tar.gz",
      sha256 = "bdd04cafc4385c3a236568127692ec197a06b97de413436623cba3e7811e010c",
      extract = true,
    } | Source,
    # leanprover-community/import-graph @ a41f0e9a4dea23188ea9cc1c41ac9f8bbafe0b93
    {
      url = "gs://minimal-staging-archives/aeneas-latest/importGraph-a41f0e9.tar.gz",
      sha256 = "578c04f8b0df045c0e4091cf3633336c4785927269ef77bb47a6080e5d3b2ca5",
      extract = true,
    } | Source,
    # leanprover-community/ProofWidgets4 @ df72b022e558978a1c50264cfc4d7fec86fa8e04
    {
      url = "gs://minimal-staging-archives/aeneas-latest/proofwidgets-df72b02.tar.gz",
      sha256 = "1eaae7c4f21d9f0d7595ff7dd8b527b8ac6c59c932c162f5bdd9116f40407dec",
      extract = true,
    } | Source,
    # leanprover-community/aesop @ 4a174c490d8707121c4a9290800489f105d85e07
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aesop-4a174c4.tar.gz",
      sha256 = "51146a125539b3eab0390c94bf90440cbfd4a4af1ab3fc3a1cc65fa49d248d98",
      extract = true,
    } | Source,
    # leanprover-community/quote4 @ dce0ad79c486cb1fb504af04f953c3466b0c6db8
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Qq-dce0ad7.tar.gz",
      sha256 = "ea7f24d48b20dc748c419a57926280de9611769f21d9db1dbb0ef7a5e536335f",
      extract = true,
    } | Source,
    # leanprover-community/batteries @ 66e469188fe07963e5cf666c7d4433f45b8131c5
    {
      url = "gs://minimal-staging-archives/aeneas-latest/batteries-66e4691.tar.gz",
      sha256 = "e186aeb771cc7abaa64a738f0cee2743e89ca34e09e7efcb48520af847e2e92d",
      extract = true,
    } | Source,
    # leanprover/lean4-cli @ c24fe6078c630e89b489bffe59b3e20ac30d12c8
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Cli-c24fe60.tar.gz",
      sha256 = "d9647a8d34708a3ecc8eb075c5c2910be9310017ecfb46c77510b2480f55285e",
      extract = true,
    } | Source,
    base,
    coreutils,
    lean,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # Same layout as aeneas-latest: oleans per Lake package, dot-free so the
  # globs see them, `usr/lib/lean/pkgs/<name>/lib/…`. A consumer runs plain
  # `lean` with
  #   LEAN_PATH=$(cat /usr/share/mathlib/LEAN_PATH)
  # The LEAN_PATH file is under usr/share/mathlib, NOT usr/lib/lean/pkgs/,
  # because aeneas-latest owns usr/lib/lean/pkgs/LEAN_PATH.
  #
  # Path overlap with aeneas-latest: both ship usr/lib/lean/pkgs/{mathlib,
  # batteries,aesop,…}/lib. The overlapping files are the same modules of the
  # same commits for the same lean, so in a closure holding both, the union
  # is a complete Mathlib whichever package wins a given path. See the PR
  # for the plan to have aeneas-latest consume this package instead.
  outputs = {
    oleans = { glob = "usr/lib/lean/pkgs/**/*.olean*" } | OutputData,
    # Language-server index; makes `lean --server` (go-to-definition into
    # Mathlib) work. Separate output so a batch consumer can subset it away.
    ileans = { glob = "usr/lib/lean/pkgs/**/*.ilean" } | OutputData,
    # Compiled IR per module: without it lean cannot run an imported module's
    # `initialize` code (pkgs#693 / aeneas-latest).
    ir = { glob = "usr/lib/lean/pkgs/**/*.ir" } | OutputData,
    ir_sig = { glob = "usr/lib/lean/pkgs/**/*.ir.sig" } | OutputData,
    share = { glob = "usr/share/mathlib/*" } | OutputData,
  },

  runtime_deps = [
    lean,
  ],

  attrs =
    {
      upstream_version = version,
      # Mathlib and the vendored Lake packages batteries, aesop, Qq,
      # ProofWidgets4, import-graph, LeanSearchClient and plausible are
      # Apache-2.0; lean4-cli is MIT, as is the npm code (React, d3, …)
      # bundled into ProofWidgets' widget JS that its oleans embed.
      license_spdx = "Apache-2.0 AND MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "leanprover-community",
        repo = "mathlib4",
      },
      # build.sh runs 8 lean jobs (LEAN_NUM_THREADS=8) for 1-2 hours.
      build_cost_multiple = 8,
    } | Attrs,

  tests = {
    # The failure that motivated the package: `Mathlib/Tactic.olean does not
    # exist`, and nothing under Real/Analysis/Topology. Import all of Mathlib
    # and use the reals; then the Mathematics-in-Lean-style header.
    imports_mathlib =
      {
        class = 'Standalone,
        test_deps = [base, lean],
        cmds = [
          ["/bin/bash", "-c", "export LEAN_PATH=$(cat /usr/share/mathlib/LEAN_PATH) && printf 'import Mathlib\\nexample (x : Real) (h : 0 <= x) : Real.sqrt (x ^ 2) = x := Real.sqrt_sq h\\n#check Real.pi\\n' > /tmp/t.lean && lean /tmp/t.lean 2>&1"],
          ["/bin/bash", "-c", "export LEAN_PATH=$(cat /usr/share/mathlib/LEAN_PATH) && printf 'import Mathlib.Tactic\\nimport Mathlib.Topology.Basic\\nexample (a b : Nat) : a + b = b + a := by ring\\nexample (s : Set Nat) : s ⊆ s := fun _ h => h\\n' > /tmp/u.lean && lean /tmp/u.lean 2>&1"],
        ],
      } | Test,
  },
} | BuildSpec
