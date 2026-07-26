let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let m4 = import "../m4/build.ncl" in
let automake = import "../automake/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.15.6" in
{
  name = "liburcu",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/urcu/userspace-rcu/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "15c341ce8b93d3b70bec120c1df90b2b02a219d65593cddeb4b52521a950e45e",
      extract = true,
      strip_prefix = "userspace-rcu-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    perl,
    m4,
    automake,
    autoconf,
    libtool,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later AND LGPL-2.1-only AND MIT AND Boehm-GC",
      source_provenance = {
        category = 'GithubRepo,
        owner = "urcu",
        repo = "userspace-rcu",
      },
    } | Attrs,
} | BuildSpec
