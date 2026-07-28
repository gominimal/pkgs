let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "10.4p1" in
{
  name = "openssh",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssh-%{version}.tar.gz",
      sha256 = "ef6026dd2aea8d56059638d5d3262902c892ceba9f88395835e0d06d3fb63238",
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
      license_spdx = "SSH-OpenSSH AND BSD-2-Clause AND BSD-3-Clause",
      repology_project = "openssh",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openssh",
        repo = "openssh-portable",
      },
    } | Attrs,
} | BuildSpec
