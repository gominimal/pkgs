let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.114.1" in
{
  name = "nushell",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nushell/nushell/%{version}.tar.gz",
      sha256 = "48ef2fb6bb3ec2b1dcff87a792aeebdfab10b29f3119a62291075b17e4ad25d5",
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
} | BuildSpec
