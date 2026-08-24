let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in

let version = "3.5.0" in

let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let xxhash = import "../xxhash/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let acl = import "../acl/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in

{
  name = "rsync",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/RsyncProject/rsync/releases/download/v%{version}/rsync-%{version}.tar.gz",
      sha256 = "c7ffd1ef653e99540f661e47cb00b7f9cad1ee6b972399b16f93d672656e0d33",
      extract = true,
      strip_prefix = "rsync-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    gcc,
    xxhash,
    openssl
  ],

  runtime_deps = [
    glibc,
    acl,
    openssl,
    coreutils
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    rsync = { glob = "usr/bin/rsync" } | OutputBin,
    "rsync-ssl" = { glob = "usr/bin/rsync-ssl" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "GPL-3.0-only",
    source_provenance = {
      category = 'GithubRepo,
      owner = "RsyncProject",
      repo = "rsync",
    },
  },
} | BuildSpec
