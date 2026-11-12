let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.20" in
{
  name = "lcms2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/mm2/Little-CMS/releases/download/lcms2.20/lcms2-2.20.tar.gz
      url = "gs://minimal-staging-archives/lcms2-%{version}.tar.gz",
      sha256 = "18ff5504fa9cc8a2b1f3591180d90ead16c8a2ea78e530523b46eab70e1ca6b9",
      extract = true,
      strip_prefix = "lcms2-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    linkicc = { glob = "usr/bin/linkicc" } | OutputBin,
    psicc = { glob = "usr/bin/psicc" } | OutputBin,
    transicc = { glob = "usr/bin/transicc" } | OutputBin,
    libs = { glob = "usr/lib/liblcms2*.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,

    includes = { glob = "usr/include/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "lcms",
      source_provenance = {
        category = 'GithubRepo,
        owner = "mm2",
        repo = "Little-CMS",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [["/usr/bin/bash", "-c", "/usr/bin/transicc -h; rc=$?; [ $rc -lt 126 ]"]],
      } | Test,
  },
} | BuildSpec
