let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "5.76.2" in
{
  name = "railway",
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
      url = "gs://minimal-staging-archives/railwayapp/cli/v%{version}.tar.gz",
      sha256 = "985f330f7502f8e31ad7afbee3742245250e7a0eef91085ef4ae914dce01f392",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    patch,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    railway = { glob = "usr/bin/railway" } | OutputBin,
  },
  attrs =
    {
      # Wire up Railway's global state directory.
      env_dir_mappings = [{ read_only = false, path = "~/.railway", class = 'State }],
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "railwayapp",
        repo = "cli",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/railway --version",
  },
} | BuildSpec
