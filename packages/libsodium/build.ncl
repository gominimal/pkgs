let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.0.21" in
{
  name = "libsodium",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/jedisct1/libsodium/releases/download/%{version}-RELEASE/libsodium-%{version}.tar.gz",
          sha256 = "9e4285c7a419e82dedb0be63a72eea357d6943bc3e28e6735bf600dd4883feaf",
          extract = true,
          strip_prefix = "libsodium-%{version}",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          # stable branch post-1.0.21: includes GCC aarch64 fix (commit 91fe8a46)
          url = "https://github.com/jedisct1/libsodium/archive/e18eee6532f5dc4b0f7ee99024e24bf4c8e12fc2.tar.gz",
          sha256 = "5fe2dfa33a2e58bf778b8ddcfe4246bf1a21bce4d007ca36170e0c85758aa66a",
          extract = true,
          strip_prefix = "libsodium-e18eee6532f5dc4b0f7ee99024e24bf4c8e12fc2",
        } | Source,
    } target,
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "jedisct1",
        repo = "libsodium",
      },
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
