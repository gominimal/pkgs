let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let patch = import "../patch/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.4.20" in
{
  name = "cups",
  build_deps = [
    { file = "build.sh" } | Local,
    # cups 2.4.20 does not compile without DNS-SD (we build with no Avahi/mDNSResponder):
    # dest.c uses _cups_getdata_t.num_local/local_dests, which 2.4.20 only declares in the
    # DNS-SD variant of the struct. Upstream OpenPrinting/cups#1739, fixed by #1740
    # (a197d30 on 2.4.x, merged 2026-10-06). Drop this patch on the bump past 2.4.20.
    { file = "0001-dest-enumeration-without-dnssd.patch" } | Local,
    {
      url = "gs://minimal-staging-archives/cups-%{version}-source.tar.gz",
      sha256 = "ab4d9cd7f3e58060091d2b24972223d6401675f11c49b65abf4f6ef31dea22ff",
      extract = true,
      strip_prefix = "cups-%{version}",
    } | Source,
    base,
    patch,
    make,
    toolchain,
    pkgconf,
  ],
  runtime_deps = [
    openssl,
    zlib,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libcups*.so*" } | OutputLib,
    includes = { glob = "usr/include/cups/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "OpenPrinting",
        repo = "cups",
      },
    } | Attrs,
} | BuildSpec
