let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "8.3" in
{
  name = "readline",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/readline-%{version}.tar.gz",
      sha256 = "fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    ncurses,
  ],
  cmd = "./build.sh",
  outputs = {
    libreadline = { glob = "usr/lib/libreadline.so*" } | OutputLib,
    libhistory = { glob = "usr/lib/libhistory.so*" } | OutputLib,

    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    headers = { glob = "usr/include/readline/*.h" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "readline",
      },
    } | Attrs,
} | BuildSpec
