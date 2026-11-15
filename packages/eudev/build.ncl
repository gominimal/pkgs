let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gperf = import "../gperf/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.3.0" in
{
  name = "eudev",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/eudev-project/eudev/releases/download/v%{version}/eudev-%{version}.tar.gz",
      sha256 = "8fba6e4f49ea4b1938828a3c2e7cc48874816c68621386e527076b6477f5d6ef",
      extract = true,
      strip_prefix = "eudev-%{version}",
    } | Source,
    base,
    gperf,
    make,
    # 3.2.15's shipped configure aborts with "pkg-config not found" without
    # it (pkgs#1093); 3.2.14's did not.
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libudev.so*" } | OutputLib,
    includes = { glob = "usr/include/libudev.h" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/libudev.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "eudev-project",
        repo = "eudev",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              gcc -x c - -o t -ludev <<'EOF'
              #include <libudev.h>
              int main(void) { struct udev *u = udev_new(); if (!u) return 1; udev_unref(u); return 0; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
