let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.42.1" in
{
  name = "util-linux",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/util-linux-%{version}.tar.xz",
      sha256 = "82e9158eb12a9b0b569d84e1687fed9dd18fe89ccd8ef5ac3427218a7c0d7f7f"
    } | Source,
    base-bootstrap,
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
      license_spdx = "GPL-2.0-or-later AND LGPL-2.1-or-later AND BSD-3-Clause",
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
        test_deps = [base-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "uuidgen > uuid.txt"],
          ["/bin/bash", "-c", "grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' uuid.txt"],
        ],
      } | Test,

    hexdump =
      {
        class = 'Standalone,
        test_deps = [base-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "echo 'ABC' > hex_test.txt"],
          ["/bin/hexdump", "-C", "hex_test.txt"],
          ["/bin/bash", "-c", "hexdump -C hex_test.txt | grep -q '41 42 43'"], # A=0x41, B=0x42, C=0x43
        ],
      } | Test,
  }
} | BuildSpec
