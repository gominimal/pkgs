let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let python = import "../python/build.ncl" in
let pcre2 = import "../pcre2/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.86.4" in
{
  name = "glib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/glib-%{version}.tar.xz",
      sha256 = "d4e2b5d791d5015ffd8c6971ad8e975a0a55c1a14926cdb25cf843ff00682260",
      extract = true,
      strip_prefix = "glib-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
    python,
  ],
  runtime_deps = [
    pcre2,
    libffi,
    zlib,
    util-linux,
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    # shell or env needed by some of the build utilities
    bins = { glob = "usr/bin/{glib-*,gdbus,gio,gobject-query,gresource,gsettings,gtester}", allow_missing_interpreter = true } | OutputBin,
    libs = { glob = "usr/lib/libg{lib,object,io,module,thread}-2.0.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    glibconfig = { glob = "usr/lib/glib-2.0/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
