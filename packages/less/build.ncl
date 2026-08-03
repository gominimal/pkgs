let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "704" in
{
  name = "less",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://www.greenwoodsoftware.com/less/less-704.tar.gz
      url = "gs://minimal-staging-archives/less-%{version}.tar.gz",
      sha256 = "20a0b0a2bb2525fa53c7eee9beb854b4c9cf172eabb209af7020743547bfe9fb"
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "gwsw",
        repo = "less",
      },
      license_spdx = "BSD-2-Clause OR GPL-3.0-or-later",
      # Home page: https://www.greenwoodsoftware.com/less/
    } | Attrs,
} | BuildSpec
