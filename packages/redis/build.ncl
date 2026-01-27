let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "8.4.0" in
{
  name = "redis",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/redis/redis/archive/refs/tags/%{version}.tar.gz",
      sha256 = "b947d9015622669b5bee8ec954f658b3278d42dbefae23a92d9b7704bfe143f9",
      extract = true,
      strip_prefix = "redis-%{version}",
    } | Source,
    bash,
    coreutils,
    grep,
    sed,
    make,
    binutils,
    gcc,
    linux_headers,
  ],

  runtime_deps = [
    glibc,
    gcc,
  ],

  cmd = "./build.sh",

  outputs = {
    redis_server = { glob = "usr/bin/redis-server" } | OutputBin,
    redis_cli = { glob = "usr/bin/redis-cli" } | OutputBin,
    redis_benchmark = { glob = "usr/bin/redis-benchmark" } | OutputBin,
    redis_check_aof = { glob = "usr/bin/redis-check-aof" } | OutputBin,
    redis_check_rdb = { glob = "usr/bin/redis-check-rdb" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "redis",
    } | Attrs,
} | BuildSpec
