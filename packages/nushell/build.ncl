let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.110.0" in
{
  name = "nushell",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nushell/nushell/%{version}.tar.gz",
      sha256 = "e4c95f743cea3d985ab90e03fd35707a46eef926d407ed363f994155c1ca5055",
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "nushell",
        repo = "nushell",
      },
    } | Attrs,
} | BuildSpec
