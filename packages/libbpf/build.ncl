let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let elfutils = import "../elfutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.7.0" in
{
  name = "libbpf",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libbpf/libbpf/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7ab5feffbf78557f626f2e3e3204788528394494715a30fc2070fcddc2051b7b",
      extract = true,
      strip_prefix = "libbpf-%{version}",
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
    # libbpf links libelf (elfutils) and zlib at build time; pkg-config must
    # find libelf.pc and the headers must be present in the build sandbox.
    elfutils,
    zlib,
  ],

  runtime_deps = [
    glibc,
    elfutils,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    libs = { glob = "usr/lib/libbpf*{.so*,.a}" } | OutputLib,
    headers = { glob = "usr/include/bpf/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-only OR BSD-2-Clause",
      repology_project = "libbpf",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libbpf",
        repo = "libbpf",
      },
    } | Attrs,
} | BuildSpec
