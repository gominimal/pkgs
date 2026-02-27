let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.4.13" in
{
  name = "cups",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/cups-%{version}-source.tar.gz",
      sha256 = "8255ecf037be72660de24a73bcada042fc5bf509fc87bc8ad16cd0675735c1a8",
      extract = true,
      strip_prefix = "cups-%{version}",
    } | Source,
    base,
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
  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -f /usr/lib/libcups.so.2 || test -f /usr/lib/x86_64-linux-gnu/libcups.so.2"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "OpenPrinting",
        repo = "cups",
      },
    } | Attrs,
} | BuildSpec
