let { Attrs, BuildSpec, Local, Needs, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.13.4" in
{
  name = "uv",
  build_deps = [
    { file = "build.sh" } | Local,
    # CVE-2026-111943 (eMudhra intermediate key compromise): pins rustls-webpki
    # 0.103.16 (RUSTSEC-2026-0382, distrusts the 8 intermediates) and
    # webpki-roots / webpki-root-certs 1.0.10 (RUSTSEC-2026-0383, drops emSign ECC
    # Root CA - G3) in upstream's Cargo.lock. Lock-only: version + checksum lines
    # (plus whatever cargo had to move with them). Drop on the first upstream
    # release whose Cargo.lock already has those versions; a version bump that
    # keeps it fails at `patch` rather than silently shipping the old lock.
    # 0.13.4's own lock already has webpki-root-certs 1.0.10, so the patch now
    # moves only rustls-webpki 0.103.14 -> 0.103.16 (aws-lc-rs 1.18.0 already
    # satisfies its ^1.18).
    { file = "cve-2026-111943-webpki-lock.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/uv-%{version}.tar.gz",
      sha256 = "182d66815490dbb497b456a6fde93c7e66ae7f27a50a2065b3b5a06fbb3a20bd"
    } | Source,
    base,
    patch,
    make,
    rust,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gcc, # TODO, weird
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
    minimal = { glob = "usr/bin/uv" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      env_state_wiring = {
        env_var = "UV_CACHE_DIR",
        prefix = "uv-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "astral-sh",
        repo = "uv",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
