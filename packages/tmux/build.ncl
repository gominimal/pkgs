let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let bison = import "../bison/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let ncurses = import "../ncurses/build.ncl" in
let libevent = import "../libevent/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.5a" in
{
  name = "tmux",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/tmux/tmux/archive/refs/tags/%{version}.tar.gz",
      sha256 = "49e68b41dec0bf408990160ee12fa29b06dee8f74c1f0b4b71c9d2a1477dd910",
      extract = true,
      strip_prefix = "tmux-%{version}",
    } | Source,
    base,
    toolchain,
    m4,
    make,
    perl,
    bison,
    autoconf,
    automake,
    pkgconf,
  ],
  runtime_deps = [
    glibc,
    ncurses,
    libevent,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    tmux = { glob = "usr/bin/tmux" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
  },
} | BuildSpec
