let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let acl = import "../acl/build.ncl" in
let base = import "../base/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "0.26" in
{
  name = "gettext",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gettext-%{version}.tar.xz",
      sha256 = "d1fb86e260cfe7da6031f94d2e44c0da55903dbae0a2fa0fae78c91ae1b56f00",
      extract = true,
      strip_prefix = "gettext-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    acl,
    ncurses,
    glibc,
    subsetOf gcc ["libgomp"],
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    libexec = { glob = "usr/libexec/gettext/*" } | OutputBin,
    datas = { glob = "usr/share/gettext/**" } | OutputData,

    ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "gettext",
      },
    } | Attrs,
} | BuildSpec
