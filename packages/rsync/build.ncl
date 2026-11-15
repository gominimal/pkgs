let { standaloneTest, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in

let version = "3.5.2" in

let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let xxhash = import "../xxhash/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let acl = import "../acl/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let zstd = import "../zstd/build.ncl" in

{
  name = "rsync",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/RsyncProject/rsync/releases/download/v%{version}/rsync-%{version}.tar.gz",
      sha256 = "a10d591825251e070f74c98df3daad195def4ed81b4a2de16169026aea33f6c8",
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
    coreutils,
    lz4,
    xxhash,
    zstd,
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

  tests = {
    smoketest = standaloneTest "/usr/bin/rsync --version",
  },
} | BuildSpec
