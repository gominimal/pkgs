let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .., } = import "minimal.ncl" in
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

let version = "3.6a" in
{
  name = "tmux",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tmux/tmux/%{version}.tar.gz",
      sha256 = "cd8d97f344cd2faa89e41358428b3ada883e4c72fd7d4f43ccac93daec1442eb",
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
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "tmux",
        repo = "tmux",
      },
    } | Attrs,
} | BuildSpec
