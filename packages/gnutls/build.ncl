let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libidn2 = import "../libidn2/build.ncl" in
let libtasn1 = import "../libtasn1/build.ncl" in
let libunistring = import "../libunistring/build.ncl" in
let make = import "../make/build.ncl" in
let nettle = import "../nettle/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.8.9" in
{
  name = "gnutls",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-%{version}.tar.xz",
      sha256 = "69e113d802d1670c4d5ac1b99040b1f2d5c7c05daec5003813c049b5184820ed",
      extract = true,
      strip_prefix = "gnutls-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    ca-certificates,
    glibc,
    gmp,
    libidn2,
    libtasn1,
    libunistring,
    nettle,
  ],

  cmd = "./build.sh",

  outputs = {
    gnutls-cli-debug = { glob = "usr/bin/gnutls-cli-debug" } | OutputBin,
    gnutls-serv = { glob = "usr/bin/gnutls-serv" } | OutputBin,
    gnutls-cli = { glob = "usr/bin/gnutls-cli" } | OutputBin,
    certtool = { glob = "usr/bin/certtool" } | OutputBin,
    psktool = { glob = "usr/bin/psktool" } | OutputBin,
    ocsptool = { glob = "usr/bin/ocsptool" } | OutputBin,
    libs = { glob = "usr/lib/libgnutls*.so*" } | OutputLib,
    includes = { glob = "usr/include/gnutls/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,
} | BuildSpec
