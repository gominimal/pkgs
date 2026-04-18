let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "692" in
{
  name = "less",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://www.greenwoodsoftware.com/less/less-692.tar.gz
      url = "gs://minimal-staging-archives/less-%{version}.tar.gz",
      sha256 = "61300f603798ecf1d7786570789f0ff3f5a1acf075a6fb9f756837d166e37d14"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    ncurses,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    less = { glob = "usr/bin/less" } | OutputBin,
    lessecho = { glob = "usr/bin/lessecho" } | OutputBin,
    lesskey = { glob = "usr/bin/lesskey" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # Home page: https://www.greenwoodsoftware.com/less/
    } | Attrs,
} | BuildSpec
