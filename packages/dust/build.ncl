let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.2.8" in
{
  name = "dust",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bootandy/dust/v%{version}.tar.gz",
      sha256 = "2df7ea0258025b2061e1a1819ee7fc48b69fbf8c084c5f0e51a457f37695453e",
      extract = true,
      strip_prefix = "dust-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    dust = { glob = "usr/bin/dust" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "bootandy",
        repo = "dust",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/dust --version",
  },
} | BuildSpec
