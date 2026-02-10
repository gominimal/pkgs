let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let m4 = import "../m4/build.ncl" in

let ncurses = import "../ncurses/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.4.1" in
{
  name = "htop",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/htop-dev/htop/%{version}.tar.gz",
      sha256 = "af9ec878f831b7c27d33e775c668ec79d569aa781861c995a0fbadc1bdb666cf",
      extract = true,
      strip_prefix = "htop-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    autoconf,
    automake,
    pkgconf,
    perl,
    m4,
  ],
  runtime_deps = [
    ncurses,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/htop" } | OutputBin,

    desktop = { glob = "usr/share/applications/*.desktop" } | OutputData,
    icons = { glob = "usr/share/icons/**" } | OutputData,
    pixmaps = { glob = "usr/share/pixmaps/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
