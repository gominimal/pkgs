let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let lean = import "../lean/build.ncl" in
let mathlib = import "../mathlib/build.ncl" in
let make = import "../make/build.ncl" in
let jq = import "../jq/build.ncl" in
let cadical = import "../cadical/build.ncl" in

# The date of the AeneasVerif/aeneas main commit this tracks (ab34bd28).
let version = "20261030" in
let aeneas_sha = "ab34bd28458a08c150b7cbf1873e59af74588138" in
{
  name = "aeneas-latest",
  # The Lean side of aeneas — the `Aeneas` Lean library that every model
  # `aeneas -backend lean` emits `import`s — built for the lean we ship,
  # against the `mathlib` package. Upstream targets the same Lean we ship
  # (lean-toolchain = leanprover/lean4:v4.35.0, Mathlib v4.35.0), so it
  # builds unpatched.
  #
  # `lean`, `mathlib-oleans`, `mathlib` and this package move TOGETHER: a
  # Mathlib tag supports exactly one Lean, and Aeneas pins one Mathlib tag.
  # build.sh refuses a lean-toolchain mismatch, and refuses a `mathlib`
  # package whose tag or Lake dependency revisions differ from the pinned
  # Aeneas source's lake-manifest.json (`mathlib` itself refuses oleans not
  # compiled from its sources). Bump lean only with an aeneas commit whose
  # backends/lean/lean-toolchain names it (pkgs#999).
  #
  # OFFLINE, no prebuilt. Mathlib comes from the `mathlib` package, compiled
  # from sha256-pinned sources (mathlib-oleans/build.ncl says why not
  # Mathlib's cache), and this package compiles only Aeneas's own ~270
  # modules with plain `lean` (see build.sh for why not lake). It installs
  # only those, and its LEAN_PATH file chains the `mathlib` package's
  # entries, so all of Mathlib is importable next to Aeneas.
  #
  # The translator (`aeneas` package) is NOT bumped here. Upstream's library is
  # now a Lean `module`; the translator's default non-module output (`import
  # Aeneas`, see aeneas/build.sh `use_lean_modules`) may import a module, and
  # the `imports_aeneas` test below checks exactly that. Bumping the
  # translator is the charon/rust-nightly cascade (`pkgmgr bundle-bump aeneas`).
  build_deps = [
    { file = "build.sh" } | Local,
    # Verbatim copy of the pinned source's backends/lean/lake-manifest.json.
    # pkgmgr reads it for Aeneas's Lean version when it checks a lean bump
    # (data/toolchain_constraints.toml); build.sh refuses a copy that
    # differs from the tarball's.
    { file = "lake-manifest.json" } | Local,
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aeneas-ab34bd2.tar.gz",
      sha256 = "cbdf6ca6efc17a994172de6f2c284b3c86807601996da417a345a7791742061b",
      extract = true,
    } | Source,
    base,
    coreutils,
    # lean and mathlib are runtime deps (below), so they are in this build
    # too.
    # build.sh orders the module builds with make and reads lean's
    # `--deps-json` header parse and the lake manifests with jq.
    make,
    jq,
    # `bv_decide` shells out to `cadical`; lean releases bundle it, ours
    # doesn't. The library build runs 60 solver call sites (Bvify's
    # `bv_decide` examples, and BvTac's `bv_tac` examples, Tests and simp
    # lemmas), so this build is the real-goal test of a cadical bump.
    cadical,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # Aeneas's oleans only, dot-free so the globs see them:
  # `usr/lib/lean/pkgs/aeneas/lib/…`. Mathlib and its dependencies are
  # `mathlib-oleans`' (via `mathlib`), under usr/lib/lean/mathlib/<name>/lib.
  # A consumer runs
  #   LEAN_PATH=$(cat /usr/lib/lean/pkgs/LEAN_PATH) lean …
  # (Aeneas first, then the mathlib package's entries); no lake downstream.
  outputs = {
    oleans = { glob = "usr/lib/lean/pkgs/**/*.olean*" } | OutputData,
    ileans = { glob = "usr/lib/lean/pkgs/**/*.ilean" } | OutputData,
    # Compiled IR per module. Without it `lean` cannot run an imported
    # module's `initialize` code and fails with "Could not find native
    # implementation of external declaration …" on the first Batteries
    # attribute registration — the same omission that broke lake in the lean
    # package (pkgs#693).
    ir = { glob = "usr/lib/lean/pkgs/**/*.ir" } | OutputData,
    ir_sig = { glob = "usr/lib/lean/pkgs/**/*.ir.sig" } | OutputData,
    lean_path = { glob = "usr/lib/lean/pkgs/LEAN_PATH" } | OutputData,
    provenance = { glob = "usr/share/aeneas-latest/*" } | OutputData,
  },

  runtime_deps = [
    lean,
    # Every Mathlib module (and batteries, aesop, Qq, ProofWidgets, ...),
    # built from source, for this build and for consumers. `mathlib` is the
    # thin layer (LEAN_PATH, MANIFEST, lake-manifest.json under
    # /usr/share/mathlib, plus the licences); the oleans are
    # `mathlib-oleans`', which `mathlib` brings in as a runtime dep, under
    # /usr/lib/lean/mathlib/<lake package>/lib. build.sh reads
    # /usr/share/mathlib/LEAN_PATH, and our LEAN_PATH file chains it.
    mathlib,
  ],

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "AeneasVerif",
        repo = "aeneas",
      },
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    # The whole point: a file that `import Aeneas` must check under the lean
    # we ship. The LEAN_PATH file is what the loadout sources.
    imports_aeneas =
      {
        class = 'Standalone,
        test_deps = [base, lean],
        cmds = [
          ["/bin/bash", "-c", "export LEAN_PATH=$(cat /usr/lib/lean/pkgs/LEAN_PATH) && printf 'import Aeneas\\nopen Aeneas.Std\\n#eval (1:Nat)+1\\n' > /tmp/t.lean && lean /tmp/t.lean"],
        ],
      } | Test,
    # All of Mathlib is reachable through the same LEAN_PATH, not only the
    # closure Aeneas imports: Real.rpow lives in
    # Mathlib.Analysis.SpecialFunctions.Pow.Real, which no Aeneas module
    # imports.
    imports_full_mathlib =
      {
        class = 'Standalone,
        test_deps = [base, lean],
        cmds = [
          ["/bin/bash", "-c", "export LEAN_PATH=$(cat /usr/lib/lean/pkgs/LEAN_PATH) && printf 'import Aeneas\\nimport Mathlib.Analysis.SpecialFunctions.Pow.Real\\nexample (x : Real) : x ^ (1 : Real) = x := Real.rpow_one x\\n#check Real.rpow_natCast\\n' > /tmp/m.lean && lean /tmp/m.lean 2>&1"],
        ],
      } | Test,
  },
} | BuildSpec
