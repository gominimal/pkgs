let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let perl = import "../perl/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let liburcu = import "../liburcu/build.ncl" in
let libcap = import "../libcap/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "9.20.20" in
{
  name = "dnsutils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.isc.org/isc/bind9/%{version}/bind-%{version}.tar.xz",
      sha256 = "19b8335d25305231d5eb8f7d924240d1ac97c4da7c93eaa6273503133aa6106a",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
    perl,
    liburcu,
    libcap,
  ],
  runtime_deps = [
    glibc,
    openssl,
    libuv,
    liburcu,
    zlib,
  ],

  needs =
    {
      dns = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    dig = { glob = "usr/bin/dig" } | OutputBin,
    host = { glob = "usr/bin/host" } | OutputBin,
    nslookup = { glob = "usr/bin/nslookup" } | OutputBin,
    nsupdate = { glob = "usr/bin/nsupdate" } | OutputBin,
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
    } | Attrs,

  tests = {
    dig_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/bash", "-c", "dig -v"]],
      } | Test,
  },
} | BuildSpec
