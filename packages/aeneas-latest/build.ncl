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
  # `aeneas -backend lean` emits `import`s — built for the lean we ship (4.34),
  # bundled with the exact Mathlib closure it pins. Upstream pins Lean 4.31.0;
  # `aeneas-lean-4.34.patch` is our port (no `sorry`, proof-script and API
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
    { file = "aeneas-lean-4.34.patch" } | Local,
    { file = "lake-manifest.json" } | Local,
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aeneas-505b6ca.tar.gz",
      sha256 = "3b52ce3f8bacb01d42124769d2c10b93b3de0b2b9f7228d9eb5ca7e06204bb3c",
      extract = true,
    } | Source,
    # leanprover-community/mathlib4 @ d13f23b723b8a846827a245b89c10fc7d3f11612 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/mathlib-d13f23b.tar.gz",
      sha256 = "6213b6243560bf435a58217af83b61b693e8d647d01dc3315f9315711acbf4e4",
      extract = true,
    } | Source,
    # leanprover-community/plausible @ 118aa17ee84656b8bd727fef7c458ee8c833385c (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/plausible-118aa17.tar.gz",
      sha256 = "dc6ce84f04e481f40984f89ea0f1ad58077693ebba989b233db508151f80be96",
      extract = true,
    } | Source,
    # leanprover-community/LeanSearchClient @ ddf04cf3949fa556442341e87d47f9f6e6074707 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/LeanSearchClient-ddf04cf.tar.gz",
      sha256 = "d3eb9a7e67a956e19ae15561c8925a7bfa7d9629342d6e4ed066baa888802d64",
      extract = true,
    } | Source,
    # leanprover-community/import-graph @ e928b72544873815af278d38681b31c0293588e3 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/importGraph-e928b72.tar.gz",
      sha256 = "cf9005ef8c691b028b94eb0567aa68a8949cc25f62ca7c04566b842f3489c088",
      extract = true,
    } | Source,
    # leanprover-community/ProofWidgets4 @ 106ff4fafc74ef4ac99d81dbf3ab399118f497a5 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/proofwidgets-106ff4f.tar.gz",
      sha256 = "42a87df5edde76ddc0830f85420449b2e982e192478da8f4ffd854da10ddffab",
      extract = true,
    } | Source,
    # leanprover-community/aesop @ 355695d523e41d0554926416cba2a2b3544fbbc9 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aesop-355695d.tar.gz",
      sha256 = "03b43b5a080e6f87458616aea0d793cfc799fb451b1df53da07fce040190648e",
      extract = true,
    } | Source,
    # leanprover-community/quote4 @ 6a489d9af5d0c47e5b259e2e8bcdfc1811b5a259 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Qq-6a489d9.tar.gz",
      sha256 = "76fcd7fdf920b1017c6dfa07784acfc8741578817b61a4d6d19903a3e42d90b8",
      extract = true,
    } | Source,
    # leanprover-community/batteries @ f2effa3d803fda822b1f97b806c47cf2adfbcbc2 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/batteries-f2effa3.tar.gz",
      sha256 = "6e61734699920cd43b2a3fbfcf888876b21ea87a96abd333094712d67375d0eb",
      extract = true,
    } | Source,
    # leanprover/lean4-cli @ e92c9f15fdfacc8536f31cfb3b7ad26c3c8cd204 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Cli-e92c9f1.tar.gz",
      sha256 = "a7e33931d7174a68264684c70be862802df320f2c82c44af6c7939538cdb3725",
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
