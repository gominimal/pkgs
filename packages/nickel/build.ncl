let { subsetOf, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.17.0" in
{
  name = "nickel",
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
      url = "https://github.com/nickel-lang/nickel/archive/refs/tags/%{version}.tar.gz",
      sha256 = "8cc47b3a2b9ed4e3b7fca06f36a8a295d231e9f8bb112d0cc02081583c189f75",
      extract = true,
      strip_prefix = "nickel-%{version}",
    } | Source,
    base,
    patch,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    nickel = { glob = "usr/bin/nickel" } | OutputBin,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "MIT",
    source_provenance = {
      category = 'GithubRepo,
      owner = "nickel-lang",
      repo = "nickel",
    },
    build_cost_multiple = 3,
  },
} | BuildSpec
