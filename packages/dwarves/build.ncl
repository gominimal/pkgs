let { Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let elfutils = import "../elfutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libbpf = import "../libbpf/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.31" in
{
  name = "dwarves",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/acmel/dwarves/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "2b6511691bda2b3ae328987092902d30fd073ef7c8754894f4a69271a66686f2",
      extract = true,
      strip_prefix = "dwarves-%{version}",
    } | Source,
    base,
    cmake,
    make,
    ninja,
    pkgconf,
    toolchain,
    # dwarves' CMake (LIBBPF_EMBEDDED=OFF) resolves these at BUILD time:
    #   pkg_check_modules(libbpf), find_package(DWARF)=libdw/elfutils,
    #   find_package(ZLIB), and argp/obstack from glibc.
    elfutils,
    glibc,
    libbpf,
    zlib,
  ],

  runtime_deps = [
    glibc,
    elfutils,
    libbpf,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libdwarves*{.so*,.a}" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      repology_project = "dwarves",
      source_provenance = {
        category = 'GithubRepo,
        owner = "acmel",
        repo = "dwarves",
      },
    } | Attrs,
} | BuildSpec
