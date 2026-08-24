let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let python = import "../python/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.1.13-stable" in
{
  name = "libevent",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libevent/libevent/releases/download/release-%{version}/libevent-%{version}.tar.gz",
      sha256 = "f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c",
      extract = true,
      strip_prefix = "libevent-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    python,
    pkgconf,
  ],
  runtime_deps = [
    glibc,
    openssl,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libevent*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libevent",
        repo = "libevent",
      },
    } | Attrs,
} | BuildSpec
