let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.47.4" in
{
  name = "e2fsprogs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v%{version}/e2fsprogs-%{version}.tar.xz",
      sha256 = "fd5bf388cbdbe006a3d3b318d983b2948382440acc85a87f1e7d108653e8db0b"
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
    bins = { glob = "usr/bin/*" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    libext2fs = { glob = "usr/lib/libext2fs*.so*" } | OutputLib,
    libcom_err = { glob = "usr/lib/libcom_err*.so*" } | OutputLib,
    libe2p = { glob = "usr/lib/libe2p*.so*" } | OutputLib,
    libss = { glob = "usr/lib/libss*.so*" } | OutputLib,
    libuuid = { glob = "usr/lib/libuuid*.so*" } | OutputLib,
    libblkid = { glob = "usr/lib/libblkid*.so*" } | OutputLib,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,

    includes = { glob = "usr/include/**/*" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "tytso",
        repo = "e2fsprogs",
      },
    } | Attrs,
} | BuildSpec
