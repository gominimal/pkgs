let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bison = import "../bison/build.ncl" in
let flex = import "../flex/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let python = import "../python/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let cairo = import "../cairo/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in
let libgd = import "../libgd/build.ncl" in
let libpng = import "../libpng/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let libwebp = import "../libwebp/build.ncl" in
let pango = import "../pango/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "14.1.1" in
{
  name = "graphviz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives//graphviz-%{version}.tar.bz2",
      sha256 = "975f4b9a7a7a7b614900ecd12919ccbd36a680818cc6fc527389b93e919410f0",
      extract = true,
      strip_prefix = "graphviz-%{version}",
    } | Source,
    base,
    bison,
    flex,
    m4,
    make,
    cmake,
    python,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    cairo,
    fontconfig,
    glibc,
    liberation-fonts,
    libgd,
    libpng,
    libtool,
    libwebp,
    pango,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    dot = { glob = "usr/bin/dot" } | OutputBin,

    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    graphviz_plugins = { glob = "usr/lib/graphviz/*.so*" } | OutputLib,
    graphviz_plugin_config = { glob = "usr/lib/graphviz/config*" } | OutputData,
    graphviz_data = { glob = "usr/share/graphviz/**" } | OutputData,

    cmake_data = { glob = "usr/lib/cmake/graphviz/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/graphviz/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "graphviz",
    } | Attrs,
} | BuildSpec
