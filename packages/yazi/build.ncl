let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "26.9.1" in
{
  name = "yazi",
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
      url = "gs://minimal-staging-archives/sxyazi/yazi/v%{version}.tar.gz",
      sha256 = "66857f1b670469daf258edd0bb2ea51d9ad3e2cab4eea9684028c80059fd6862",
      extract = true,
      strip_prefix = "yazi-%{version}",
    } | Source,
    base,
    patch,
    rust,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  # Surfaces `version` to build.sh as MINIMAL_ARG_VERSION, which stamps the
  # build-time VERGEN_GIT_SHA yazi-version demands (no git in the sandbox).
  build_args = {
    include version,
  },

  outputs = {
    yazi = { glob = "usr/bin/yazi" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "yazi",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sxyazi",
        repo = "yazi",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
