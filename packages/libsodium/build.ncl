let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.0.21" in
{
  name = "libsodium",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/jedisct1/libsodium/releases/download/%{version}-RELEASE/libsodium-%{version}.tar.gz",
      sha256 = "9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf",
      extract = true,
      strip_prefix = "libsodium-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libsodium.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libsodium.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "libsodium",
    } | Attrs,

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <sodium.h>\n#include <stdio.h>\nint main() { if (sodium_init() < 0) return 1; printf(\"ok\\n\"); return 0; }' > test.c"],
          ["/bin/gcc", "test.c", "-lsodium", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^ok$'"],
        ],
      } | Test,
  },
} | BuildSpec
