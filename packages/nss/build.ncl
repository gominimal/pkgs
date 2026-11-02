let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in

let nspr = import "../nspr/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.132" in
{
  name = "nss",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/nss-%{version}.tar.gz",
      sha256 = "ee9cf4837ba801141a804321c4462ad8f452ff4314275c6d5108a6b05af227ff",
      extract = true,
      strip_prefix = "nss-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    perl,
  ],
  runtime_deps = [
    nspr,
    zlib,
    sqlite,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/lib{nss3,nssutil3,smime3,ssl3,softokn3,freeblpriv3}.so*" } | OutputLib,
    bins = { glob = "usr/bin/{certutil,pk12util}" } | OutputBin,
    includes = { glob = "usr/include/nss/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/nss.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MPL-2.0",
    } | Attrs,
} | BuildSpec
