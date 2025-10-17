let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let automake = import "../automake/build.ncl" in
let gettext = import "../gettext/build.ncl" in
let git = import "../git/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let flex = import "../flex/build.ncl" in
let groff = import "../groff/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let m4 = import "../m4/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let python = import "../python/build.ncl" in
let wget = import "../wget/build.ncl" in
let patch = import "../patch/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let libpipeline = import "../libpipeline/build.ncl" in
let shadow = import "../shadow/build.ncl" in
let less = import "../less/build.ncl" in
# let libseccomp = import "../libseccomp/build.ncl" in
{
  name = "man-db",
  inputs = [
    { file = "build.sh" } | Local,
    {
      # https://gitlab.com/man-db/man-db/-/archive/2.13.1/man-db-2.13.1.tar.gz",
      url = "gs://minimal-staging-archives/man-db-2.13.1.tar.gz",
      sha256 = "8d14b10f8e295fa40d6a1975817ead1d80c2f085794d2d9e2e1179fa0cb54132",
    } | Source,
    base,
    toolchain,
    flex,
    groff,
    gdbm,
    ca-certificates,
    make,
    autoconf,
    perl,
    automake,
    gettext,
    git,
    zlib,
    libtool,
    m4,
    python,
    wget,
    patch,
    pkgconf,
    libpipeline,
    shadow, # useradd
    # libseccomp
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
    libs = { glob = "usr/lib/**" } | OutputLib,
    libExec = { glob = "usr/libexec/man-db/*" } | OutputLib,
    etc = { glob = "usr/etc/*" } | OutputData,
    docs = { glob = "usr/share/doc/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locale = { glob = "usr/share/locale/**" } | OutputData,
  },
} | BuildSpec
