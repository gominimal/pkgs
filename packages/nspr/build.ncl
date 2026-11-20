let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.41" in
{
  name = "nspr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nspr-%{version}.tar.gz",
      sha256 = "c562b8ddfe93704b7dc077be013f01448fdc6c124b1821c0f10471a71cb2e9e6",
      extract = true,
      strip_prefix = "nspr-%{version}",
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
    libs = { glob = "usr/lib/lib{nspr4,plc4,plds4}.so*" } | OutputLib,
    bins = { glob = "usr/bin/nspr-config", allow_missing_interpreter = true } | OutputBin,
    includes = { glob = "usr/include/nspr/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MPL-2.0",
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [["/bin/bash", "-c", "/usr/bin/nspr-config --version"]],
      } | Test,
  },
} | BuildSpec
