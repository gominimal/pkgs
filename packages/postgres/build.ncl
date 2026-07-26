let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let base = import "../base/build.ncl" in
let flex = import "../flex/build.ncl" in
let bison = import "../bison/build.ncl" in
let m4 = import "../m4/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let openssl = import "../openssl/build.ncl" in
let readline = import "../readline/build.ncl" in
let icu = import "../icu/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "18.4" in
{
  name = "postgres",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/postgresql-%{version}.tar.gz",
      sha256 = "450aa8f2da06c46f8221916e82ae06b04fb1040f8f00643dbf8b7d663caac0b9",
    } | Source,
    base,
    make,
    perl,
    toolchain,
    flex,
    bison,
    m4,
    pkgconf,
  ],
  runtime_deps = [
    openssl,
    readline,
    icu,
    zstd,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/**", allow_data = true } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    share = { glob = "usr/share/postgresql/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "PostgreSQL",
      source_provenance = {
        category = 'GithubRepo,
        owner = "postgres",
        repo = "postgres",
      },
    } | Attrs,
} | BuildSpec
