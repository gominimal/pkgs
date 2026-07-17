# libtecla (Tecla) — interactive command-line editing library. A Maude build
# prerequisite; see pkgmgr-rs#528. MIT-style permissive (Martin C. Shepherd).
# Upstream is an academic site (sites.astro.caltech.edu) with no git host or
# canonical release archive, so the tarball is mirrored to gs:// like the other
# archive sources; there is no `source_provenance` category that fits it.
let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "1.6.3" in
{
  name = "libtecla",
  build_deps = [
    { file = "build.sh" } | Local,
    # libtecla's bundled config.guess/config.sub are from 2003 and don't know
    # aarch64; build.sh overwrites them with these modern (2024) copies so
    # configure can canonicalize the build triple on both arches. (#528)
    { file = "config.guess" } | Local,
    { file = "config.sub" } | Local,
    {
      url = "gs://minimal-staging-archives/libtecla-%{version}.tar.gz",
      sha256 = "f2757cc55040859fcf8f59a0b7b26e0184a22bece44ed9568a4534a478c1ee1a",
      extract = true,
      # The tarball entries are `./libtecla/…` (a leading `./`), so a
      # `strip_prefix = "libtecla"` doesn't match — extract as-is and `cd
      # libtecla` in build.sh instead. Tecla builds in its own source tree.
    } | Source,
    base,
    make,
    toolchain,
    ncurses,
  ],
  runtime_deps = [
    glibc,
    ncurses,
  ],
  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
