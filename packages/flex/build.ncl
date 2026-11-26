let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "2.7.10" in
{
  name = "flex",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/flex-%{version}.tar.gz",
      sha256 = "d303c2956792acd8bf3601effef76cadc85a7876852cb66da411c0d5d2f868f4"
    } | Source,
    base-bootstrap,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    flex = { glob = "usr/bin/flex" } | OutputBin,
    flexpp = { glob = "usr/bin/flex++" } | OutputBin,

    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause-flex",
      source_provenance = {
        category = 'GithubRepo,
        owner = "westes",
        repo = "flex",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/flex --version",
  },
} | BuildSpec
