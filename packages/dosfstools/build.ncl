let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.2" in
{
  name = "dosfstools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/dosfstools/dosfstools/releases/download/v%{version}/dosfstools-%{version}.tar.gz",
      sha256 = "64926eebf90092dca21b14259a5301b7b98e7b1943e8a201c7d726084809b527"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    mans = { glob = "usr/share/man/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "dosfstools",
        repo = "dosfstools",
      },
    } | Attrs,
} | BuildSpec
