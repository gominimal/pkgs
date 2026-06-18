let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bc = import "../bc/build.ncl" in
let bison = import "../bison/build.ncl" in
let cpio = import "../cpio/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let flex = import "../flex/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let patch = import "../patch/build.ncl" in
let perl = import "../perl/build.ncl" in
let pyelftools = import "../pyelftools/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "5.5.0" in
{
  name = "libkrunfw",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/containers/libkrunfw/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "b0cbf1450269c80aea1dccbf440011deb2762a098b338c234079a6ef06456ead",
      extract = true,
      strip_prefix = "libkrunfw-%{version}",
    } | Source,
    # Guest kernel firmware source, vendored so the build is hermetic (the
    # Makefile otherwise curls it into tarballs/ at build time).
    {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.91.tar.xz",
      sha256 = "0ff2ab9e169f9f1948557471fbb450d3018f8c5b77caf288e1a3982582597969",
    } | Source,
    base,
    toolchain,
    make,
    flex,
    bison,
    m4,
    bc,
    cpio,
    elfutils,
    openssl,
    perl,
    patch,
    python,
    pyelftools,
  ],

  runtime_deps = [glibc],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libkrunfw.so*" } | OutputLib,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "containers",
      repo = "libkrunfw",
    },
  },
} | BuildSpec
