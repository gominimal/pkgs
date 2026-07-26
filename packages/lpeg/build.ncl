let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let luajit = import "../luajit/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# PEG pattern-matching library for Lua, built as a Lua 5.1 C module against
# the luajit headers. Canonical source is Roberto Ierusalimschy's PUC-Rio
# page (not a GitHub or GNU project, so source_provenance is omitted).
let version = "1.1.0" in
{
  name = "lpeg",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://www.inf.puc-rio.br/~roberto/lpeg/lpeg-%{version}.tar.gz",
      sha256 = "4b155d67d2246c1ffa7ad7bc466c1ea899bbc40fef0257cc9c03cecbaed4352a",
      extract = true,
      strip_prefix = "lpeg-%{version}",
    } | Source,
    base,
    luajit,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    module = { glob = "usr/lib/lua/5.1/*.so" } | OutputLib,
    data = { glob = "usr/share/lua/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base, luajit],
        cmds = [
          ["/bin/bash", "-c", "luajit -e 'assert(require(\"lpeg\").match ~= nil)'"],
        ],
      } | Test,
  },
} | BuildSpec
