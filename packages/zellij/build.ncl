let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "0.43.1" in
{
  name = "zellij",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zellij-org/zellij/v%{version}.tar.gz",
      sha256 = "e9fd24190869be6e9e8d731df2ccd0b3b1dd368ae9dbb9d620ec905b83e325ec",
      extract = true,
      strip_prefix = "zellij-%{version}",
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
    zellij = { glob = "usr/bin/zellij" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "zellij-org",
        repo = "zellij",
      },
    } | Attrs,
} | BuildSpec
