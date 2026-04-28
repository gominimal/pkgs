let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let libpsl = import "../libpsl/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.19.0" in
{
  name = "curl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/curl-%{version}.tar.xz",
      sha256 = "4eb41489790d19e190d7ac7e18e82857cdd68af8f4e66b292ced562d333f11df",
      extract = true,
      strip_prefix = "curl-%{version}",
    } | Source,
    base,
    make,
    perl,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    libpsl,
    openssl,
    zlib,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  outputs = {
    curl = { glob = "usr/bin/curl" } | OutputBin,
    curl-config = { glob = "usr/bin/curl-config", allow_missing_interpreter = true } | OutputBin,
    wcurl = { glob = "usr/bin/wcurl", allow_missing_interpreter = true } | OutputBin,
    libs = { glob = "usr/lib/libcurl.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libcurl.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/curl/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "curl",
      repology_project = "curl",
      source_provenance = {
        category = 'GithubRepo,
        owner = "curl",
        repo = "curl",
      },
    } | Attrs,
} | BuildSpec
