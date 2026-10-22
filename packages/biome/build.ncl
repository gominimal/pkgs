let { standaloneTest, subsetOf, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.5.15" in
{
  name = "biome",

  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-111943 (eMudhra intermediate key compromise): pins rustls-webpki
    # 0.103.16 (RUSTSEC-2026-0382, distrusts the 8 intermediates) and
    # webpki-roots / webpki-root-certs 1.0.10 (RUSTSEC-2026-0383, drops emSign ECC
    # Root CA - G3) in upstream's Cargo.lock. Lock-only: version + checksum lines
    # (plus whatever cargo had to move with them). Drop on the first upstream
    # release whose Cargo.lock already has those versions; a version bump that
    # keeps it fails at `patch` rather than silently shipping the old lock.
    { file = "cve-2026-111943-webpki-lock.patch" } | Local,
    {
      url = "https://github.com/biomejs/biome/archive/refs/tags/@biomejs/biome@%{version}.tar.gz",
      sha256 = "0212a8f9e351e2d47580cf8371948dd477ceb01e0fef1a65f81061a2a4a39039",
      extract = true,
      strip_prefix = "biome--biomejs-biome-%{version}",
    } | Source,
    base,
    patch,
    make,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/biome" } | OutputBin,
  },

  needs = {
    internet = {},
  },

  attrs = {
    upstream_version = version,
    license_spdx = "MIT OR Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "biomejs",
      repo = "biome",
    },
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/biome --version",

    # Regression test for gominimal/pkgs#637. biome_cli's Cargo version is
    # literally "0.0.0" — upstream stamps the real one through BIOME_VERSION at
    # compile time — so an unstamped build reports 0.0.0 and biome then warns
    # that every `$schema` in a config "does not match the CLI version". Assert
    # the exact string: a substring match would still pass on "0.0.0".
    version_is_stamped =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(/usr/bin/biome --version)\" = 'Version: %{version}'"],
        ],
      } | Test,
  },
} | BuildSpec
