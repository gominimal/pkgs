let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let sed = import "../sed/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "3.15.0" in
{
  name = "pciutils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pciutils-%{version}.tar.gz",
      sha256 = "a42e6e3f76fb6b1f6ac2e08cdd151f6bf78bc4f6312c591f4b6ec197582ede3a"
    } | Source,
    base,
    sed,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
  ],
  cmd = "./build.sh",
  outputs = {
    lspci = { glob = "usr/bin/lspci" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    libs = { glob = "usr/lib/*" } | OutputLib,

    includes = { glob = "usr/include/**/*" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pciutils",
        repo = "pciutils",
      },
    } | Attrs,
} | BuildSpec
