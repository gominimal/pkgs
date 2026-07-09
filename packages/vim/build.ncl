let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let acl = import "../acl/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "9.2.0782" in
{
  name = "vim",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vim-%{version}.tar.gz",
      sha256 = "148ad1c29555e0cf6430570730d8b9fc97151a814866e6f549e5e73e4ad0a612"
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    acl,
    ncurses,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    vim = { glob = "usr/bin/vim" } | OutputBin,
    vimdiff = { glob = "usr/bin/vimdiff" } | OutputBin,

    data = { glob = "usr/share/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Vim",
      source_provenance = {
        category = 'GithubRepo,
        owner = "vim",
        repo = "vim",
      },
    } | Attrs,
} | BuildSpec
