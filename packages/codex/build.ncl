let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let libcap = import "../libcap/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let git = import "../git/build.ncl" in

let version = "0.155.0" in
{
  name = "codex",
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
      url = "https://github.com/openai/codex/archive/refs/tags/rust-v%{version}.tar.gz",
      sha256 = "8bb3b5a5693492926b53c51ee2e68822b057d712b2ca1a0ae67878557fd6a2ea",
      extract = true,
      strip_prefix = "codex-rust-v%{version}",
    } | Source,
    base,
    patch,
    rust,
    toolchain,
    pkgconf,
    cmake,
    llvm,
    openssl,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    openssl,
    libcap,
    git,
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

  outputs = {
    codex = { glob = "usr/bin/codex" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openai",
        repo = "codex",
      },
      build_cost_multiple = 3,
      env_dir_mappings = [{ read_only = false, path = "~/.codex", class = 'State }],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/codex --version",
  },
} | BuildSpec
