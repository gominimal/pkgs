let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "8.12.0" in
{
  name = "redis",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/redis/redis/%{version}.tar.gz",
      sha256 = "07e2477372566acf587e32c1abc8af088ad901fb2c725388ec9a5bef29c47319",
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
    # redis-server/redis-check-* call pthread_cancel (and backtrace() in the
    # crash log); glibc dlopens libgcc_s.so.1 to unwind and aborts without it.
    # A dlopen is not DT_NEEDED. No redis ELF NEEDs libstdc++ (amd64 + arm64).
    subsetOf gcc-runtime ["libgcc"],
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

  tests = {
    smoketest = standaloneTest "/usr/bin/redis-server --version",
  },
} | BuildSpec
