let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let acl = import "../acl/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "9.2.1345" in
{
  name = "vim",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vim-%{version}.tar.gz",
      sha256 = "ddae84ef8d9e8fcca1ec6e501a41235a2466e935a27d6a95e3a84677f84b8fb4"
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
    # vim, its ex/view/rvim/rview/vimdiff links, xxd and the vimtutor sh script.
    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,

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

  tests = {
    smoketest = standaloneTest "/usr/bin/vim --version",
  },
} | BuildSpec
