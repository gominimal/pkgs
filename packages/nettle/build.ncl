let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "3.10.1" in
{
  name = "nettle",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://ftpmirror.gnu.org/nettle/nettle-%{version}.tar.gz",
      sha256 = "b0fcdd7fc0cdea6e80dcf1dd85ba794af0d5b4a57e26397eee3bc193272d9132",
      extract = true,
      strip_prefix = "nettle-%{version}",
    } | Source,
    base,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gmp,
  ],

  cmd = "./build.sh",

  outputs = {
    nettle-pbkdf2 = { glob = "usr/bin/nettle-pbkdf2" } | OutputBin,
    nettle-lfib-stream = { glob = "usr/bin/nettle-lfib-stream" } | OutputBin,
    nettle-hash = { glob = "usr/bin/nettle-hash" } | OutputBin,
    sexp-conv = { glob = "usr/bin/sexp-conv" } | OutputBin,
    pkcs1-conv = { glob = "usr/bin/pkcs1-conv" } | OutputBin,
    libs = { glob = "usr/lib/lib{nettle,hogweed}.so*" } | OutputLib,
    includes = { glob = "usr/include/nettle/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "nettle",
      },
    } | Attrs,
} | BuildSpec
