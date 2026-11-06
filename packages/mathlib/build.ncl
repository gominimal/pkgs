let { Attrs, BuildSpec, Local, OutputData, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let lean = import "../lean/build.ncl" in
let mathlib-oleans = import "../mathlib-oleans/build.ncl" in

# Mathlib's release tag for the lean we ship (leanprover-community/mathlib4
# tag v4.35.0 = 56a005855ea17e0b0958f73ec801ae140b0a1679). Must equal
# mathlib-oleans' version; build.sh refuses a mismatch.
let version = "4.35.0" in
{
  name = "mathlib",
  # ALL of Mathlib, compiled from source for the lean we ship: 8,625 modules
  # (Mathlib.lean + Mathlib/**), plus the Lake packages it requires. This is
  # what `import Mathlib`, Mathematics in Lean and anything touching
  # Real/Analysis/Topology need.
  #
  # TWO PACKAGES. The compile is `mathlib-oleans` (nine sha256-pinned Sources
  # + lean, ~35 min on build-bot). This package is the thin layer on top
  # that builds in seconds: the upstream licences, the third-party notices
  # for ProofWidgets' widget JS/WebAssembly, LEAN_PATH, MANIFEST and Mathlib's
  # lake-manifest.json. An edit to this package's build.sh changes only its
  # spec hash, not mathlib-oleans' (pkgs#1244). Install THIS one:
  # mathlib-oleans is its runtime dep, so the oleans come with it, under
  # usr/lib/lean/mathlib/<lake package>/lib.
  #
  # The notices are checked against the exact ProofWidgets bundles the oleans
  # embed. This package takes the same nine Sources (one sources.ncl, so they
  # cannot drift), checks the bundle sha256 pins in the notice files against
  # them, and refuses to package if they differ from the hashes mathlib-oleans
  # recorded at compile time (usr/share/mathlib-oleans/), so a changed
  # bundle fails packaging.
  #
  # The licences and notices (notices.ncl, install-licences.sh) are shipped
  # by mathlib-oleans too, under usr/share/licenses/mathlib-oleans, so that
  # package is complete on its own; editing them therefore rebuilds both.
  #
  # `lean`, `mathlib-oleans`, `mathlib` and `aeneas-latest` move TOGETHER: a
  # Mathlib tag supports exactly one Lean; build.sh refuses a mismatch. Bump
  # this with lean.
  build_deps =
    [
      { file = "build.sh" } | Local,
      base,
      # lean and mathlib-oleans are runtime deps (below), so they are in
      # this build too.
    ]
    # The licence installer and the four third-party notices (shared with
    # mathlib-oleans).
    @ (import "notices.ncl")
    # The nine pinned sources (for their LICENSE files, lake-manifest.json and
    # ProofWidgets' widget bundles): the same file mathlib-oleans compiles.
    @ (import "../mathlib-oleans/sources.ncl"),

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # The oleans are mathlib-oleans' (usr/lib/lean/mathlib/<name>/lib/…),
  # brought in as a runtime dep. A consumer runs plain `lean` with
  #   LEAN_PATH=$(cat /usr/share/mathlib/LEAN_PATH)
  outputs = {
    # LEAN_PATH, MANIFEST, lake-manifest.json.
    share = { glob = "usr/share/mathlib/*" } | OutputData,
    # Every upstream LICENSE (+ any NOTICE), one dir per source, and the
    # ProofWidgets JS third-party inventory. Required for redistribution.
    licenses = { glob = "usr/share/licenses/mathlib/**" } | OutputData,
  },

  runtime_deps = [
    lean,
    mathlib-oleans,
  ],

  attrs =
    {
      upstream_version = version,
      # Verified against the LICENSE file in each pinned tarball
      # (install-licences.sh installs them and fails closed if one is
      # missing or differs):
      #   Apache-2.0: Mathlib, batteries, aesop, Qq, ProofWidgets4,
      #               import-graph, LeanSearchClient, plausible
      #   MIT:        lean4-cli
      # No source ships a NOTICE file. ProofWidgets' oleans also embed its
      # prebuilt widget JS, which bundles npm code; the licences of the 281
      # npm tarballs its package-lock.json resolves (a superset of what is
      # bundled; inventory in proofwidgets-js-third-party.txt, verbatim
      # texts in proofwidgets-js-NOTICE.txt) add ISC, BSD-3-Clause,
      # CC-BY-4.0, CC0-1.0 and Unlicense. Two of those bundles also embed a
      # WebAssembly build of Graphviz 15.0.0 (via @hpcc-js/wasm): EPL-2.0,
      # with its lib/vpsc under CPL-1.0, plus expat, Emscripten and its musl
      # libc (MIT), and LLVM's libc++, libc++abi, libunwind and compiler-rt
      # (Apache-2.0 WITH LLVM-exception); the JS that decodes it inlines
      # fzstd (MIT) and @hpcc-js/esbuild-plugins' basE91 loader (Apache-2.0).
      # EPL/CPL are weak (file-level) copyleft: redistributing the unmodified
      # object code needs the licence texts and a source offer, both in
      # proofwidgets-wasm-NOTICE.txt (pkgmgr-rs#1181). The offer names
      # upstream and our own mirror copies of the Graphviz 15.0.0 source and
      # the hpcc-js-wasm wasm-v2.34.2 recipe (gs://minimal-staging-archives,
      # sha256s in the notice). The corresponding-source CI check probes only
      # the Source URLs (mathlib-oleans/sources.ncl, used by both
      # packages), which are all mirrored; it cannot see source
      # compiled into a bundled blob, so those copies are what it would miss.
      # penroseCanvas.js / penroseDisplay.js embed @penrose/optimizer 3.2.0,
      # Rust compiled to WebAssembly: 24 crates plus the Rust 1.71.1 std and
      # its registry crates, all MIT / Apache-2.0 (nalgebra 0.31.1 ships an
      # Apache-2.0 LICENSE but declares BSD-3-Clause; both texts are
      # reproduced; some crates also offer Zlib or NCSA, which we do not
      # elect). Their notices are in proofwidgets-penrose-wasm-NOTICE.txt.
      license_spdx = "Apache-2.0 AND MIT AND ISC AND BSD-3-Clause AND CC-BY-4.0 AND CC0-1.0 AND Unlicense AND EPL-2.0 AND CPL-1.0 AND Apache-2.0 WITH LLVM-exception",
      # Every licence above permits binary redistribution with notices (and,
      # for EPL-2.0/CPL-1.0, a source offer), which the `licenses` output
      # carries, so the public cache may serve the prebuilt artifacts (users
      # skip the ~35 min compile, which is mathlib-oleans'). Explicit rather
      # than the stdlib default so the decision is visible and reviewable.
      redistributable = true,
      source_provenance = {
        category = 'GithubRepo,
        owner = "leanprover-community",
        repo = "mathlib4",
      },
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
