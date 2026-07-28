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

let version = "15.1.0" in
{
  name = "graphviz",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/graphviz-%{version}.tar.xz",
      sha256 = "4c44f9f6654d39638db7cdb6a088735117469015299298d82087b24dd4042b16",
      extract = true,
      # No `strip_prefix`. graphviz 15.1.0 added a HARDLINK
      # (redhat/graphviz.spec.rhel.in -> redhat/graphviz.spec.fedora.in), and
      # the prefix-stripping extraction path cannot place one: it strips the
      # prefix from the entry's destination but passes the link TARGET through
      # verbatim, still carrying `graphviz-15.1.0/`, so the link resolves
      # outside the stripped tree and fails with ENOENT. The no-strip path uses
      # whole-archive unpack, which resolves link targets against the
      # destination root and handles this correctly.
      #
      # So: extract with the prefix intact and `cd` into it from build.sh, the
      # same shape bash/binutils/coreutils already use.
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
  # Exposes MINIMAL_ARG_VERSION so build.sh can enter the unstripped
  # source directory.
  build_args = {
    include version,
  },
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
      license_spdx = "EPL-1.0",
      repology_project = "graphviz",
    } | Attrs,
} | BuildSpec
