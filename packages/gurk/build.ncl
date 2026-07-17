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

let version = "0.9.3" in
{
  name = "gurk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/boxdot/gurk-rs/v%{version}.tar.gz",
      sha256 = "1c8ee4466374375a3df2ccd94fcc86d76bfcdd868820f3f9d4a1f2cbed2be22b",
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
