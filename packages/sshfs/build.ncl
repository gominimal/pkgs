let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let libfuse = import "../libfuse/build.ncl" in
let glib = import "../glib/build.ncl" in

let version = "3.7.7" in
{
  name = "sshfs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libfuse/sshfs/sshfs-%{version}.tar.xz",
      sha256 = "893013ce6cdbf6f9fa790c9a4ca2b07eea95139f965f5c14f06b458cbe17f00d",
      extract = true,
      strip_prefix = "sshfs-%{version}",
    } | Source,
    base,
    toolchain,
    pkgconf,
    make,
    cmake,
    ninja,
    meson,
  ],
  runtime_deps = [
    glibc,
    libfuse,
    glib,
  ],

  cmd = "./build.sh",
  outputs = {
    sshfs = { glob = "usr/bin/sshfs" } | OutputBin,
    sbins = { glob = "usr/sbin/**" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      repology_project = "sshfs",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libfuse",
        repo = "sshfs",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/sshfs --version",
  },
} | BuildSpec
