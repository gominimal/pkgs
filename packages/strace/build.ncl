let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let file = import "../file/build.ncl" in

let version = "7.2" in
{
  name = "strace",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/strace-%{version}.tar.xz",
      sha256 = "4bde6246926890dcee824f6e6ac42a06752f47d77e5097d86e3c0d6d4b709fe5"
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
