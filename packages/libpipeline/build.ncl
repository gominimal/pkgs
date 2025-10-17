let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
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
let bash = import "../bash/build.ncl" in
let m4 = import "../m4/build.ncl" in
let libtool = import "../libtool/build.ncl" in
# let libseccomp = import "../libseccomp/build.ncl" in
{
  name = "libpipeline",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://gitlab.com/libpipeline/libpipeline/-/archive/1.5.8/libpipeline-1.5.8.tar.gz",
      sha256 = "ada309694ee87ed564a798e7f6ceab70f577f922e0c0e2fe81018ddfe218ca51",
    } | Source,
    base,
    toolchain,
    flex,
    groff, # needed?
    gdbm,  # needed?
    ca-certificates, # needed?
    make,
    autoconf,
    automake,
    m4,
    perl,
    gettext,
    pkgconf,
    git,
    zlib,
    bash,
    libtool,

    # libseccomp
  ],
  runtime_deps = [
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    pkgconf = { glob = "usr/lib/pkgconfig/libpipeline.pc" } | OutputLib,
    includes = { glob = "usr/include/*.h" } | OutputLib,
    docs = { glob = "usr/share/man/man3/*" } | OutputLib,
  },
} | BuildSpec
