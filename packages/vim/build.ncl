let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let acl = import "../acl/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "9.2.0804" in
{
  name = "vim",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vim-%{version}.tar.gz",
      sha256 = "d10040a537b3cd85b671a35b69236c071418fcf04fd0e4cb93d1b4eb11f10541"
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
