let { standaloneTest, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.1" in
{
  name = "picocom",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/npat-efault/picocom/archive/refs/tags/%{version}.tar.gz",
      sha256 = "e6761ca932ffc6d09bd6b11ff018bdaf70b287ce518b3282d29e0270e88420bb",
      extract = true,
      strip_prefix = "picocom-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/picocom" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/picocom --help",
  },

  attrs = {
    upstream_version = version,
    license_spdx = "GPL-2.0-or-later",
    source_provenance = {
      category = 'GithubRepo,
      owner = "npat-efault",
      repo = "picocom",
    },
  },
} | BuildSpec
