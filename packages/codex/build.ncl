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

let version = "0.164.0" in
{
  name = "codex",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/openai/codex/archive/refs/tags/rust-v%{version}.tar.gz",
      sha256 = "57f8c2f88fe5b6eaf08672212b6372362ca044bee43d6e57b6ad032152be772e",
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
