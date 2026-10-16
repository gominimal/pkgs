let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let bdwgc = import "../bdwgc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libunistring = import "../libunistring/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
let readline = import "../readline/build.ncl" in # the REPL; guile-readline.so links it

# GNU Guile, built from its C sources: build.sh deletes the tarball's prebuilt .go bytecode, so every
# compiled module comes from the C interpreter bootstrapping the compiler. The one pre-generated input
# kept is module/ice-9/psyntax-pp.scm, the macro expander expanded by itself (Scheme source).
let version = "3.0.11" in
{
  name = "guile",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/guile-%{version}.tar.xz",
      sha256 = "818c79d236657a7fa96fb364137cc7b41b3bdee0d65c6174ca03769559579460",
      # untarred by build.sh: prebuilt/<triple>/Makefile.in are hard links, which extraction drops
      extract = false,
    } | Source,
    base,
    make,
    pkgconf,
    toolchain,
    bdwgc,
    gmp,
    libffi,
    libunistring,
    tar,
    xz,
    readline,
  ],
  runtime_deps = [
    glibc,
    bdwgc,
    gmp,
    libffi,
    libunistring,
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    # compiled modules and extensions
    modules = { glob = "usr/lib/guile/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    # Scheme sources and aclocal macros
    share = { glob = "usr/share/{guile,aclocal}/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-3.0-or-later",
      repology_project = "guile",
      build_cost_multiple = 2,
      source_provenance = {
        category = 'GnuProject,
        name = "guile",
      },
    } | Attrs,

  tests = {
    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(GUILE_AUTO_COMPILE=0 guile -c '(display (version))')\" = 3.0.11"],
          ["/bin/bash", "-c", "test \"$(GUILE_AUTO_COMPILE=0 guile -c '(use-modules (srfi srfi-1)) (display (fold + 0 (iota 101)))')\" = 5050"],
        ],
      } | Test,
  },
} | BuildSpec
