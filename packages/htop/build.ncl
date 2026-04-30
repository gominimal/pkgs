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

let version = "3.5.1" in
{
  name = "htop",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/htop-dev/htop/%{version}.tar.gz",
      sha256 = "dfc4a09845e9bc86f466a722e62b8f87d59028ff39689077ff2257a6a605061d",
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
      license_spdx = "GPL-2.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "htop-dev",
        repo = "htop",
      },
    } | Attrs,
} | BuildSpec
