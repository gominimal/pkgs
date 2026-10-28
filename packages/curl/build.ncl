let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let libpsl = import "../libpsl/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let nghttp2 = import "../nghttp2/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "8.23.0" in
{
  name = "curl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/curl-%{version}.tar.xz",
      sha256 = "8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5",
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
    # HTTP/2 (nghttp2), as Arch/Debian/Fedora ship curl. Also what lets
    # curl-sys users (zellij, via isahc's http2 feature) link this libcurl:
    # curl-sys checks `curl-config --features` for HTTP2 and otherwise compiles
    # its bundled curl, whose 8.4.0 copy does not build on OpenSSL 4.
    nghttp2,
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
