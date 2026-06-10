let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "52.0" in
{
  name = "cloud-hypervisor",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cloud-hypervisor/cloud-hypervisor/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "20f0e2c9cbd9cb912500ea0f755f96aebe1d7cc5e2a4a546df344e7af0eab015",
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
    subsetOf gcc ["libgcc"],
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
