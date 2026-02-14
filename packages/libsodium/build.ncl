let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.0.21" in
{
  name = "libsodium",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/jedisct1/libsodium/archive/refs/tags/%{version}-RELEASE.tar.gz",
      sha256 = "42e0ca94faaec901f4fbeda84b1b94b18f5309c360c66345cf52a7ab515b245b",
      extract = true,
      strip_prefix = "libsodium-%{version}-RELEASE",
    } | Source,
    base,
    make,
    autoconf,
    automake,
    libtool,
    m4,
    perl,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libsodium.so*" } | OutputLib,
    includes = { glob = "usr/include/sodium/**" } | OutputData,
    sodium_h = { glob = "usr/include/sodium.h" } | OutputData,
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
        test_deps = [bash, gcc, binutils],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <sodium.h>\n#include <stdio.h>\nint main() { if (sodium_init() < 0) return 1; printf(\"ok\\n\"); return 0; }' > test.c"],
          ["/bin/gcc", "test.c", "-lsodium", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^ok$'"],
        ],
      } | Test,
  },
} | BuildSpec
