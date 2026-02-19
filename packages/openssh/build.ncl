let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "10.2p1" in
{
  name = "openssh",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssh-%{version}.tar.gz",
      sha256 = "ccc42c0419937959263fa1dbd16dafc18c56b984c03562d2937ce56a60f798b2",
      extract = true,
      strip_prefix = "openssh-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    openssl,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/**" } | OutputBin,
    sbins = { glob = "usr/sbin/**" } | OutputBin,

    etcs = { glob = "etc/ssh/**" } | OutputData,

    libexec = { glob = "usr/libexec/*" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "openssh",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openssh",
        repo = "openssh-portable",
      },
    } | Attrs,
} | BuildSpec
