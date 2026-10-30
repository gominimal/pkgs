let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let libcap = import "../libcap/build.ncl" in
let patch = import "../patch/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let git = import "../git/build.ncl" in

let version = "0.165.0" in
{
  name = "codex",
  build_deps = [
    { file = "build.sh" } | Local,
    # OpenSSL 4: Cargo.lock's openssl-sys 0.9.111 panics in its build script on 4.x
    # (4.x support starts at 0.9.114). Moves it to 0.9.117 and openssl to 0.10.81. Applied by name, so a
    # stale patch fails the build.
    { file = "openssl-4-openssl-sys-lock.patch" } | Local,
    {
      url = "https://github.com/openai/codex/archive/refs/tags/rust-v%{version}.tar.gz",
      sha256 = "4e066a7dbd1234efa7458c2b137161bb7ddde1dde6be4ed4c8f38e6c45f862ab",
      extract = true,
      strip_prefix = "codex-rust-v%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    pkgconf,
    cmake,
    llvm,
    openssl,
    patch,
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
      # codegen-units=1 roughly doubled the build (~22 → ~46 min).
      build_cost_multiple = 6,
      env_dir_mappings = [{ read_only = false, path = "~/.codex", class = 'State }],
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/codex --version",
  },
} | BuildSpec
