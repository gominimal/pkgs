let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.0.3" in
{
  name = "libfdk-aac",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-%{version}.tar.gz",
      sha256 = "829b6b89eef382409cda6857fd82af84fabb63417b08ede9ea7a553f811cb79e",
      extract = true,
      strip_prefix = "fdk-aac-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libfdk-aac.so*" } | OutputLib,
    includes = { glob = "usr/include/fdk-aac/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
