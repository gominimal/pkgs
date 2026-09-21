let { Attrs, BuildSpec, Local, Needs, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let lean = import "../lean/build.ncl" in
let curl = import "../curl/build.ncl" in
let git = import "../git/build.ncl" in
let patch = import "../patch/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let leangz = import "../leangz/build.ncl" in
let cadical = import "../cadical/build.ncl" in

# The date of the AeneasVerif/aeneas nightly this tracks (505b6ca3).
let version = "20260912" in
let aeneas_sha = "505b6ca35217e7be5c96c3e2f8045edfbdf47291" in
{
  name = "aeneas-latest",
  # The Lean side of aeneas — the `Aeneas` Lean library that every model
  # `aeneas -backend lean` emits `import`s — built for the lean we ship (4.33),
  # bundled with the exact Mathlib closure it pins. Upstream pins Lean 4.31.0;
  # `aeneas-lean-4.33.patch` is our port (no `sorry`, proof-script and API
  # renames only; notes in gominimal/aeneas-lab port/NOTES.md).
  #
  # Offline-lake mechanism adopted from nixpkgs `pkgs/build-support/lake`
  # (MIT, © Eelco Dolstra and the Nixpkgs/NixOS contributors): every Lake
  # dependency is a pinned source placed under `.lake/packages/<name>`, an
  # on-disk `.lake/package-overrides.json` tells lake to use those directories,
  # `LAKE_NO_CACHE=1` + an empty `RESERVOIR_API_URL` keep it from reaching out.
  # The ONE network use is Mathlib's own build cache (`lake exe cache get`),
  # fetching only the olean closure of the 28 Mathlib modules Aeneas imports
  # (1,181 files, ~900 MB, versus 5.9 GB for all of Mathlib). Those files are
  # content-addressed, so two builds are byte-identical.
  #
  # The translator (`aeneas` package, July commit) is NOT bumped here: its
  # output checks against this library (verified 2026-09-12). Bumping it means
  # charon b104e24 + rust nightly 2026-08-18 — a separate cascade.
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "aeneas-lean-4.33.patch" } | Local,
    { file = "lake-manifest.json" } | Local,
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aeneas-505b6ca.tar.gz",
      sha256 = "3b52ce3f8bacb01d42124769d2c10b93b3de0b2b9f7228d9eb5ca7e06204bb3c",
      extract = true,
    } | Source,
    # leanprover-community/mathlib4 @ db584cd6d46c92f209a44c0f1c829460d327499d (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/mathlib-db584cd.tar.gz",
      sha256 = "4a2ac3460ebf81f0b55a88dbea45f767ad0a3aae3dc7e4e3310d0a63805e71eb",
      extract = true,
    } | Source,
    # leanprover-community/plausible @ b7eb3304aeae834b12dda98993a37f6a41f6f0bb (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/plausible-b7eb330.tar.gz",
      sha256 = "cf4662201a44459275f16be2980ca980902308cd2115dc2e03a4e60e45d8ea2a",
      extract = true,
    } | Source,
    # leanprover-community/LeanSearchClient @ 5f4d51b81cbd3f6b32b156bfad9056621a040404 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/LeanSearchClient-5f4d51b.tar.gz",
      sha256 = "c32fc5803c32e4182f778ce9d2f234e988c23d657a0cab5c4a1d995dcda1bb15",
      extract = true,
    } | Source,
    # leanprover-community/import-graph @ 16f02aa7642864af59f1ff0e384a015994db9118 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/importGraph-16f02aa.tar.gz",
      sha256 = "693dfaa9a4520ffd6faa29957a7ed6cf27a70c520f75494eea8fa7b6b7f3b523",
      extract = true,
    } | Source,
    # leanprover-community/ProofWidgets4 @ 4be2e3d5087eeb272cf5a8853b8f9dd025ef5957 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/proofwidgets-4be2e3d.tar.gz",
      sha256 = "b1710af25f520ded1159a9b2dd9ec1e252b461b93413b9c57a4d62b853df2006",
      extract = true,
    } | Source,
    # leanprover-community/aesop @ 3448c0bcc5ce01b2d1546e483ec3620e32df3d0e (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aesop-3448c0b.tar.gz",
      sha256 = "f90c627c791a5abc91f5bb589dc0373f1d75065f2b2138bd1408f9a81b99f181",
      extract = true,
    } | Source,
    # leanprover-community/quote4 @ 92c15be17b7caf78c2ad767ec40f89052d908d81 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Qq-92c15be.tar.gz",
      sha256 = "7bc4082c4ecccb58ce944473670a3989a555a1e14b1d34d6e2cc52ae4ca71d4f",
      extract = true,
    } | Source,
    # leanprover-community/batteries @ 4488d40d070b9700d4d5a6aa342f0d40c31b2a2d (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/batteries-4488d40.tar.gz",
      sha256 = "627f7e0333ec067775f4debc3af107119865119afed5c73c98db48208c4f2b01",
      extract = true,
    } | Source,
    # leanprover/lean4-cli @ 6130a47896ce867c6a4a55373441e59e565bad0f (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Cli-6130a47.tar.gz",
      sha256 = "5aef433582bb36ebc9c30c0c0943bad889125bddf3b922593e0437fef37445bc",
      extract = true,
    } | Source,
    base,
    coreutils,
    lean,
    # `lake exe cache get` first compiles Mathlib's cache tool to a native
    # executable (Lean → C → object), so a C toolchain is needed even though
    # the library itself is oleans only. `leangz` provides the `leantar` the
    # cache tool needs to unpack `.ltar` files (an official Lean release
    # bundles it; our from-source lean does not).
    toolchain,
    leangz,
    # `bv_decide` (exercised by Bvify's own `#guard_msgs` examples during the
    # library build) shells out to `cadical`; lean releases bundle it, ours
    # doesn't.
    cadical,
    curl,
    git,
    patch,
    ca-certificates,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  # Oleans only, one directory per Lake package, dot-free so the globs see
  # them: `usr/lib/lean/pkgs/<name>/lib/…`. A consumer sets
  #   LEAN_PATH=/usr/lib/lean/pkgs/aeneas/lib:/usr/lib/lean/pkgs/mathlib/lib:…
  # (see the aeneas loadout) and runs plain `lean`; no lake needed downstream.
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
  },
} | BuildSpec
