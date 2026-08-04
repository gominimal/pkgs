let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in

let version = "0.8.3" in

let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

{
  name = "xxhash",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Cyan4973/xxHash/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "aae608dfe8213dfd05d909a57718ef82f30722c392344583d3f39050c7f29a80",
      extract = true,
      strip_prefix = "xxHash-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    gcc
  ],

  runtime_deps = [
    glibc
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/{*.so*,*.a*}" } | OutputLib,
    headers = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    man = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "Cyan4973",
      repo = "xxHash",
    },
  },
} | BuildSpec
