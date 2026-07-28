let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
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

let version = "3.7" in
{
  name = "tmux",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/tmux/tmux/%{version}.tar.gz",
      sha256 = "123b9ed37c7ee957327a483024ea6ae0e6032348c02680be2ac91b9350e62d36",
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
      license_spdx = "ISC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "tmux",
        repo = "tmux",
      },
    } | Attrs,
} | BuildSpec
