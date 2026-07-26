let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let protobuf = import "../protobuf/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.10.0" in
{
  name = "gurk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/boxdot/gurk-rs/v%{version}.tar.gz",
      sha256 = "8db5a45dfc1502be589d5ea633320cec94dcbbd4b38f489404b784d4b4aa702e",
      extract = true,
      strip_prefix = "gurk-rs-%{version}",
    } | Source,
    base,
    pkgconf,
    perl,
    protobuf,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    openssl,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    gurk = { glob = "usr/bin/gurk" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "AGPL-3.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "boxdot",
        repo = "gurk-rs",
      },
    } | Attrs,

  tests.smoketest = standaloneTest "/usr/bin/gurk --version",
} | BuildSpec
