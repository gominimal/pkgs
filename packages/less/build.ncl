let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
{
  name = "less",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/less-679.tar.gz",
      sha256 = "9b68820c34fa8a0af6b0e01b74f0298bcdd40a0489c61649b47058908a153d78"
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
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
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
    } | Attrs,
} | BuildSpec
