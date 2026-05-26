let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let m4 = import "../m4/build.ncl" in

let ncurses = import "../ncurses/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.0" in
{
  name = "cmatrix",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/abishekvashok/cmatrix/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "ad93ba39acd383696ab6a9ebbed1259ecf2d3cf9f49d6b97038c66f80749e99a",
      extract = true,
      strip_prefix = "cmatrix-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    autoconf,
    automake,
    m4,
  ],
  runtime_deps = [
    ncurses,
    glibc,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/cmatrix" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "abishekvashok",
        repo = "cmatrix",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/cmatrix -V",
  },
} | BuildSpec
