let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let libpsl = import "../libpsl/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.25.0" in
{
  name = "wget",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/wget-%{version}.tar.gz",
      sha256 = "766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784",
      extract = true,
      strip_prefix = "wget-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
  ],
  runtime_deps = [
    glibc,
    libpsl,
    openssl,
    pcre2,
    zlib,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    wget = { glob = "usr/bin/wget" } | OutputBin,
    wgetrc = { glob = "etc/wgetrc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "wget",
      },
    } | Attrs,
} | BuildSpec
