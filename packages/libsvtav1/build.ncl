let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.2.0" in
{
  name = "libsvtav1",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/v%{version}/SVT-AV1-v%{version}.tar.bz2",
      sha256 = "512f2ea5649e3e76c2dddcc25c2556fb67a9582baaab207c9c96161c94659dad",
      extract = true,
      strip_prefix = "SVT-AV1-v%{version}",
    } | Source,
    base,
    toolchain,
    cmake,
    make,
    nasm,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/SvtAv1*" } | OutputBin,
    libs = { glob = "usr/lib/libSvtAv1*.so*" } | OutputLib,
    includes = { glob = "usr/include/svt-av1/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "(BSD-2-Clause AND BSD-3-Clause-Clear)",
      source_provenance = {
        category = 'GithubRepo,
        owner = "AOMediaCodec",
        repo = "SVT-AV1",
      },
    } | Attrs,
} | BuildSpec
