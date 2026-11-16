let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let patch = import "../patch/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let curl = import "../curl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

let version = "0.46.0" in
{
  name = "zellij",
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
    # OpenSSL 4: Cargo.lock's openssl-sys 0.9.111 panics in its build script on 4.x
    # (4.x support starts at 0.9.114). Moves it to 0.9.117. Applied by name, so a
    # stale patch fails the build.
    { file = "openssl-4-openssl-sys-lock.patch" } | Local,
    # OpenSSL 4: drop isahc's `http2` feature (Cargo.toml + the matching
    # Cargo.lock edit cargo would make: libnghttp2-sys goes). With http2 on,
    # curl-sys only links a system libcurl that reports HTTP2, and ours has no
    # nghttp2 (adding it would cycle curl -> nghttp2 -> cmake -> curl), so it
    # compiled its bundled curl 8.4.0, which does not build on OpenSSL 4.
    { file = "openssl-4-no-isahc-http2.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/zellij-org/zellij/v%{version}.tar.gz",
      sha256 = "2dfa237fea447f3cc98954e81b0097b9d25841010036720e11f67880fe7861f0",
      extract = true,
      strip_prefix = "zellij-%{version}",
    } | Source,
    base,
    patch,
    rust,
    toolchain,
    openssl,
    # OpenSSL 4: build without zellij's default `vendored_curl` feature, so
    # curl-sys links this system libcurl (found through pkgconf) instead of
    # compiling its bundled curl 8.4.0, which reads OpenSSL's now-opaque
    # ASN1_INTEGER and fails on 4.x (see build.sh).
    pkgconf,
    curl,
    # CVE-2026-119375 (RUSTSEC-2026-0459): link this system SQLite (3.54.1, fixed
    # in 3.54.0) instead of the copy rusqlite's `bundled` feature compiles in.
    # libsqlite3-sys 0.27.0 bundles a pre-3.54.0 SQLite, and only its bundled
    # build is affected. See build.sh.
    sqlite,
  ],

  runtime_deps = [
    glibc,
    gcc,
    openssl,
    subsetOf curl ["libs"],
    subsetOf sqlite ["libs"],
    # The system libcurl verifies TLS against /etc/ssl/certs (AGENTS.md trust
    # store rule): bring the store in so HTTPS works in an isolated loadout.
    ca-certificates,
  ],

  cmd = "./build.sh",

  outputs = {
    zellij = { glob = "usr/bin/zellij" } | OutputBin,
    bash_completion = { glob = "usr/share/bash-completion/completions/zellij" } | OutputData,
    fish_completion = { glob = "usr/share/fish/vendor_completions.d/zellij.fish" } | OutputData,
    zsh_completion = { glob = "usr/share/zsh/site-functions/_zellij" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "zellij-org",
        repo = "zellij",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/zellij --version",
  },
} | BuildSpec
