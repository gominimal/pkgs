let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let acl = import "../acl/build.ncl" in
let base = import "../base/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.0" in
{
  name = "gettext",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gettext-%{version}.tar.xz",
      sha256 = "71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7",
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
  build_args = {
    include version,
  },

  outputs = {
    # Theres a few binaries which depend on /bin/sh, we dont depend on bash as a runtime dep because it will
    # bloat our deps and also an environment which is likely to use these tools (a build) is pretty much guaranteed
    # to have a shell wired.

    bins = { glob = "usr/bin/*", allow_missing_interpreter = true } | OutputBin,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    libexec = { glob = "usr/libexec/gettext/*", allow_missing_interpreter = true } | OutputBin,
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
