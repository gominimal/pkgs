let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let groff = import "../groff/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let libpipeline = import "../libpipeline/build.ncl" in
let less = import "../less/build.ncl" in
{
  name = "man-db",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://download.savannah.gnu.org/releases/man-db/man-db-2.13.1.tar.xz
      url = "gs://minimal-staging-archives/man-db-2.13.1.tar.xz",
      sha256 = "8afebb6f7eb6bb8542929458841f5c7e6f240e30c86358c1fbcefbea076c87d9",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
  ],
  runtime_deps = [
    gdbm,
    groff,
    libpipeline,
    less,
  ],

  cmd = "./build.sh",
  outputs = {
    sbins = { glob = "usr/sbin/*" } | OutputBin,
    bins = { glob = "usr/bin/*" } | OutputBin,

    libs = { glob = "usr/lib/man-db/libman*.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/man-db/*.la" } | OutputData,
    libexec = { glob = "usr/libexec/man-db/*" } | OutputLib,

    etc = { glob = "usr/etc/*" } | OutputData,
    docs = { glob = "usr/share/doc/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locale = { glob = "usr/share/locale/**" } | OutputData,
  },
} | BuildSpec
