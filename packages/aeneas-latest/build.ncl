let { Attrs, BuildSpec, Local, Needs, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let lean = import "../lean/build.ncl" in
let curl = import "../curl/build.ncl" in
let git = import "../git/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let leangz = import "../leangz/build.ncl" in
let cadical = import "../cadical/build.ncl" in

# The date of the AeneasVerif/aeneas main commit this tracks (fdebf20d).
let version = "20261022" in
let aeneas_sha = "fdebf20d78e8007bb92fc17068f17fc2e6cfbbbf" in
{
  name = "aeneas-latest",
  # The Lean side of aeneas — the `Aeneas` Lean library that every model
  # `aeneas -backend lean` emits `import`s — built for the lean we ship,
  # bundled with the exact Mathlib closure it pins. Upstream now targets the
  # same Lean we ship (lean-toolchain = leanprover/lean4:v4.35.0, Mathlib
  # v4.35.0), so it builds unpatched; the old 4.34 port patch is gone.
  #
  # `lean` and this package move TOGETHER: Mathlib's own tooling is compiled
  # against the running Lean, so a Mathlib pinned for one Lean minor does not
  # build on the next (lean 4.35's Lake changed `PackageEntrySrc.path`, which
  # broke the Sept pin's `Cache/Requests.lean`; pkgs#999). Bump lean only with
  # an aeneas commit whose backends/lean/lean-toolchain names it.
  #
  # Offline-lake mechanism adopted from nixpkgs `pkgs/build-support/lake`
  # (MIT, © Eelco Dolstra and the Nixpkgs/NixOS contributors): every Lake
  # dependency is a pinned source placed under `.lake/packages/<name>`, an
  # on-disk `.lake/package-overrides.json` tells lake to use those directories,
  # `LAKE_NO_CACHE=1` + an empty `RESERVOIR_API_URL` keep it from reaching out.
  # The ONE network use is Mathlib's own build cache (`lake exe cache get`),
  # fetching only the olean closure of the 31 Mathlib modules Aeneas imports
  # (1,181 files, ~900 MB, versus 5.9 GB for all of Mathlib). Those files are
  # content-addressed, so two builds are byte-identical.
  #
  # The translator (`aeneas` package) is NOT bumped here. Upstream's library is
  # now a Lean `module`; the translator's default non-module output (`import
  # Aeneas`, see aeneas/build.sh `use_lean_modules`) may import a module, and
  # the `imports_aeneas` test below checks exactly that. Bumping the
  # translator is the charon/rust-nightly cascade (`pkgmgr bundle-bump aeneas`).
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "lake-manifest.json" } | Local,
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aeneas-fdebf20.tar.gz",
      sha256 = "476496fbe2c47e8cf0be818d92b0ba38d7f36cde67b245f78f755440af6decda",
      extract = true,
    } | Source,
    # leanprover-community/mathlib4 @ 56a005855ea17e0b0958f73ec801ae140b0a1679 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/mathlib-56a0058.tar.gz",
      sha256 = "45567f6e07607b787026d287c8ec1828f6cabc8debe11a45a521750580e3a0d5",
      extract = true,
    } | Source,
    # leanprover-community/plausible @ dfa4f38190d07c37e315953e08b90fe2d95b3c24 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/plausible-dfa4f38.tar.gz",
      sha256 = "3f157cbc2450a6d14f32f18c7a1efd12ee8209a335b3c8ea05248eece9beb342",
      extract = true,
    } | Source,
    # leanprover-community/LeanSearchClient @ d6b4c7be5be75ec4917c873ac50c756dc1436372 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/LeanSearchClient-d6b4c7b.tar.gz",
      sha256 = "bdd04cafc4385c3a236568127692ec197a06b97de413436623cba3e7811e010c",
      extract = true,
    } | Source,
    # leanprover-community/import-graph @ a41f0e9a4dea23188ea9cc1c41ac9f8bbafe0b93 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/importGraph-a41f0e9.tar.gz",
      sha256 = "578c04f8b0df045c0e4091cf3633336c4785927269ef77bb47a6080e5d3b2ca5",
      extract = true,
    } | Source,
    # leanprover-community/ProofWidgets4 @ df72b022e558978a1c50264cfc4d7fec86fa8e04 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/proofwidgets-df72b02.tar.gz",
      sha256 = "1eaae7c4f21d9f0d7595ff7dd8b527b8ac6c59c932c162f5bdd9116f40407dec",
      extract = true,
    } | Source,
    # leanprover-community/aesop @ 4a174c490d8707121c4a9290800489f105d85e07 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/aesop-4a174c4.tar.gz",
      sha256 = "51146a125539b3eab0390c94bf90440cbfd4a4af1ab3fc3a1cc65fa49d248d98",
      extract = true,
    } | Source,
    # leanprover-community/quote4 @ dce0ad79c486cb1fb504af04f953c3466b0c6db8 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Qq-dce0ad7.tar.gz",
      sha256 = "ea7f24d48b20dc748c419a57926280de9611769f21d9db1dbb0ef7a5e536335f",
      extract = true,
    } | Source,
    # leanprover-community/batteries @ 66e469188fe07963e5cf666c7d4433f45b8131c5 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/batteries-66e4691.tar.gz",
      sha256 = "e186aeb771cc7abaa64a738f0cee2743e89ca34e09e7efcb48520af847e2e92d",
      extract = true,
    } | Source,
    # leanprover/lean4-cli @ c24fe6078c630e89b489bffe59b3e20ac30d12c8 (lake-manifest.json)
    {
      url = "gs://minimal-staging-archives/aeneas-latest/Cli-c24fe60.tar.gz",
      sha256 = "d9647a8d34708a3ecc8eb075c5c2910be9310017ecfb46c77510b2480f55285e",
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
