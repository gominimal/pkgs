let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
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

let version = "0.130.0" in
{
  name = "codex",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/openai/codex/archive/refs/tags/rust-v%{version}.tar.gz",
      sha256 = "13fac7f7aa8ef2e2747696ae2681bd2129f31f0f592a9d276af9780234f4fdf0",
      extract = true,
      strip_prefix = "codex-rust-v%{version}",
    } | Source,
    # rusty_v8 prebuilt static lib — the v8 crate's build.rs downloads it
    # from github at build time (blocked in CS; the bindings are already in
    # the cargo vendor). extract=false: it's a gzipped .a, not a tarball, so
    # it hydrates to /build/<basename> and build.sh gunzips it + points
    # RUSTY_V8_ARCHIVE at the .a.
    {
      url = "https://github.com/denoland/rusty_v8/releases/download/v146.4.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz",
      sha256 = "e64b4d99e4ae293a2e846244a89b80178ba10382c13fb591c1fa6968f5291153",
      extract = false,
    } | Source,
    base,
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
