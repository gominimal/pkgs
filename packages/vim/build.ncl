let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let acl = import "../acl/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "9.2.0470" in
{
  name = "vim",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vim-%{version}.tar.gz",
      sha256 = "9dbaaab1c79f67628e72c52ab7180c509a4ed433b4df31cb9fce485ccf5c599d"
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
