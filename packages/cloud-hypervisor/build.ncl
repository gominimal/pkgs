let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "55.0" in
{
  name = "cloud-hypervisor",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cloud-hypervisor/cloud-hypervisor/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "8fa9d34b127c3cad84732a2d13c9117a6abdf4f7bdc9bd7a800efd9a418d6a22",
      extract = true,
      strip_prefix = "cloud-hypervisor-%{version}",
    } | Source,
    base,
    openssl,
    rust,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    openssl,
    subsetOf gcc-runtime ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    cloud-hypervisor = { glob = "usr/bin/cloud-hypervisor" } | OutputBin,
    ch-remote = { glob = "usr/bin/ch-remote" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/cloud-hypervisor --version",
    ch_remote_help = standaloneTest "/bin/ch-remote --help",
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0 AND BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cloud-hypervisor",
        repo = "cloud-hypervisor",
      },
    } | Attrs,
} | BuildSpec
