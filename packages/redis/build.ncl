let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "8.10.0" in
{
  name = "redis",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/redis/redis/%{version}.tar.gz",
      sha256 = "b928cf47427b94bb0c6866c32df834bc8e5efc815b9ad2e2d24bf33f2c533e2a",
      extract = true,
      strip_prefix = "redis-%{version}",
    } | Source,
    bash,
    coreutils,
    gawk,
    grep,
    sed,
    make,
    binutils,
    gcc,
    linux_headers,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libstdcpp"],
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
      license_spdx = "AGPL-3.0-only OR SSPL-1.0",
      repology_project = "redis",
      source_provenance = {
        category = 'GithubRepo,
        owner = "redis",
        repo = "redis",
      },
    } | Attrs,
} | BuildSpec
