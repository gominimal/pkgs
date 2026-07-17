let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let file = import "../file/build.ncl" in

let version = "7.1" in
{
  name = "strace",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/strace-%{version}.tar.xz",
      sha256 = "81743ecf2a5b44186b2f5038afdc8beda7e5c70aed15b4fbfbcc6e9ece24490f"
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    strace = { glob = "usr/bin/strace" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "strace",
        repo = "strace",
      },
    } | Attrs,
} | BuildSpec
