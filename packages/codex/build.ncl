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

let version = "0.116.0" in
{
  name = "codex",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/openai/codex/archive/refs/tags/rust-v%{version}.tar.gz",
      sha256 = "37affa694148a0fdda1bd8f335de86075a517cb9bd45b21d798bc47550115b38",
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
