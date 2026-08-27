let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.115.1" in
{
  name = "nushell",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nushell/nushell/%{version}.tar.gz",
      sha256 = "06df93281a0f858019d09ea6cf821b19a7cd9017cdfb9e898cfe8dd4bd8101c2",
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
