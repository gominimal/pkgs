let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.2.7" in
{
  name = "dust",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/bootandy/dust/v%{version}.tar.gz",
      sha256 = "923a2eed637d2ea5f4ad5f820b6f87cc6e0081cfa4bc5ed1fe09278dd74db963",
      extract = true,
      strip_prefix = "dust-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
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
