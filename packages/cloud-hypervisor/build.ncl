let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "51.1" in
{
  name = "cloud-hypervisor",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cloud-hypervisor/cloud-hypervisor/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "a2393046c0230f6360792ed2ef1b60968aa4e04d12b6be419c86306774e2e4ef",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "cloud-hypervisor",
        repo = "cloud-hypervisor",
      },
    } | Attrs,
} | BuildSpec
