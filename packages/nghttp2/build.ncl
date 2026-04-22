let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.68.1" in
{
  name = "nghttp2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nghttp2/nghttp2/releases/download/v%{version}/nghttp2-%{version}.tar.gz",
      sha256 = "ceb434c1f9dfe2a9d305b6b797786fb9227484dfa88508d14ca1c50263db55d3",
      extract = true,
      strip_prefix = "nghttp2-%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
    pkgconf,
    openssl,
    zlib,
  ],
  runtime_deps = [
    glibc,
    openssl,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libnghttp2.so*" } | OutputLib,
    includes = { glob = "usr/include/nghttp2/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libnghttp2.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/nghttp2/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "nghttp2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nghttp2",
        repo = "nghttp2",
      },
    } | Attrs,

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <nghttp2/nghttp2.h>\n#include <stdio.h>\nint main() { printf(\"%s\\n\", nghttp2_version(0)->version_str); return 0; }' > test.c"],
          ["/bin/gcc", "test.c", "-lnghttp2", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^1\\.'"],
        ],
      } | Test,
  },
} | BuildSpec
