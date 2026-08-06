let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in

let version = "3.4.4" in

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
      sha256 = "bd88cf82fa653da32314fb229136407c5c90f80d1758d8f4b091767877d8fa96",
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
    source_provenance = {
      category = 'GithubRepo,
      owner = "RsyncProject",
      repo = "rsync",
    },
  },
} | BuildSpec
