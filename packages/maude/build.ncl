# Maude — a high-performance reflective rewriting-logic engine (C++). The runtime
# backend tamarin-prover shells out to. Source-built: the release ships prebuilt
# linux-x86_64 only (no aarch64), and minimal builds both arches. Links minimal's
# SHARED gmp/libsigsegv/libtecla/buddy — Maude's INSTALL assumes STATIC libs (and
# hides the .so's), but minimal ships them --disable-static, so we link
# dynamically. CVC4 + Yices2 SMT backends disabled to start. See pkgmgr-rs#528.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } =
  import "minimal.ncl"
in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let flex = import "../flex/build.ncl" in
let bison = import "../bison/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libsigsegv = import "../libsigsegv/build.ncl" in
let libtecla = import "../libtecla/build.ncl" in
let buddy = import "../buddy/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "3.5.1" in
{
  name = "maude",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/maude-%{version}.tar.gz",
      sha256 = "3dce4f7b42fae2430a08ab2663303d1be244792bb3cc365c58cdb2f3f7bff170",
      extract = true,
      strip_prefix = "Maude-Maude%{version}",
    } | Source,
    base,
    make,
    toolchain,
    autoconf,
    automake,
    libtool,
    m4,
    flex,
    bison,
    gmp,
    libsigsegv,
    libtecla,
    buddy,
    ncurses,
  ],
  runtime_deps = [
    glibc,
    gmp,
    libsigsegv,
    libtecla,
    buddy,
    ncurses,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    maude = { glob = "usr/bin/maude" } | OutputBin,
    share = { glob = "usr/share/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "maude-lang",
        repo = "Maude",
      },
      build_cost_multiple = 5,
    } | Attrs,
} | BuildSpec
