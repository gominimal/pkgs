let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.41.2" in
{
  name = "util-linux",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/util-linux-%{version}.tar.xz",
      sha256 = "6062a1d89b571a61932e6fc0211f36060c4183568b81ee866cf363bce9f6583e"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    libblkid = { glob = "usr/lib/libblkid*.so*" } | OutputLib,
    libfdisk = { glob = "usr/lib/libfdisk*.so*" } | OutputLib,
    libmount = { glob = "usr/lib/libmount*.so*" } | OutputLib,
    libsmartcols = { glob = "usr/lib/libsmartcols*.so*" } | OutputLib,
    libuuid = { glob = "usr/lib/libuuid*.so*" } | OutputLib,
    libs = { glob = "usr/lib/lib*.{a,so*}" } | OutputLib,

    includes = { glob = "usr/include/**/*" } | OutputData,
    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**/*" } | OutputData,

    completions = { glob = "usr/share/bash-completion/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "util-linux",
        repo = "util-linux",
      },
    } | Attrs,

  tests = {
    smoketest_uuidgen =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "uuidgen > uuid.txt"],
          ["/bin/bash", "-c", "grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' uuid.txt"],
        ],
      } | Test,

    hexdump =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'ABC' > hex_test.txt"],
          ["/bin/hexdump", "-C", "hex_test.txt"],
          ["/bin/bash", "-c", "hexdump -C hex_test.txt | grep -q '41 42 43'"], # A=0x41, B=0x42, C=0x43
        ],
      } | Test,
  }
} | BuildSpec
