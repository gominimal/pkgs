let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.117.0" in
{
  name = "nushell",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nushell/nushell/%{version}.tar.gz",
      sha256 = "ccb5640f8f88b48787c946daf87a349972b939c2edbc5a3b4ca6fc0921bddd6b",
      extract = true,
      strip_prefix = "nushell-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    openssl,
  ],

  runtime_deps = [
    glibc,
    gcc,
    openssl,
  ],

  cmd = "./build.sh",

  outputs = {
    nu = { glob = "usr/bin/nu" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nushell",
        repo = "nushell",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/nu --version",
  },
} | BuildSpec
