let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.0.6" in
{
  name = "drift",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/aymanbagabas/drift/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "814c26bcb8973423534d2a31ccc0a03383e4aa8d4a0d847eecca1e427f6ac5d3",
      extract = true,
      strip_prefix = "drift-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  # drift is a pager for `git diff`: every view it renders comes from shelling
  # out to git (src/git.rs), so git is a hard runtime dep, not a convenience.
  # The library set is just what the binary actually links -- syntect is built
  # with the `default-fancy` feature (pure-Rust fancy-regex), so unlike delta
  # there is no oniguruma here, and nothing pulls in zlib.
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    git,
  ],

  # Source archive is the plain GitHub tag tarball with no vendored crates, so
  # the build resolves its cargo deps over the network.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    drift = { glob = "usr/bin/drift" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "aymanbagabas",
        repo = "drift",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/drift --version",
  },
} | BuildSpec
