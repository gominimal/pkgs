let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.11.1" in
{
  name = "libssh2",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-%{version}.tar.gz",
      sha256 = "82b35c61c78b475647bdc981a183c5b5ab0d979e1caee94186e8f9150f2b0d0d",
      extract = true,
      strip_prefix = "libssh2-libssh2-%{version}",
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
    libs = { glob = "usr/lib/libssh2.so*" } | OutputLib,
    includes = { glob = "usr/include/libssh2*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libssh2.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/libssh2/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libssh2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libssh2",
        repo = "libssh2",
      },
    } | Attrs,

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [bash, gcc, binutils],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <libssh2.h>\n#include <stdio.h>\nint main() { printf(\"%s\\n\", libssh2_version(0)); return 0; }' > test.c"],
          ["/bin/gcc", "test.c", "-lssh2", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^1\\.'"],
        ],
      } | Test,
  },
} | BuildSpec
