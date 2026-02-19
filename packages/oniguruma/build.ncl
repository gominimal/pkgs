let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "6.9.10" in
{
  name = "oniguruma",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/kkos/oniguruma/releases/download/v%{version}/onig-%{version}.tar.gz",
      sha256 = "2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05",
      extract = true,
      strip_prefix = "onig-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libonig.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libonig.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "kkos",
        repo = "oniguruma",
      },
    } | Attrs,
} | BuildSpec
