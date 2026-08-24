let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let expat = import "../expat/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let make = import "../make/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let readline = import "../readline/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let version = "17.2" in
{
  name = "gdb",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gdb-%{version}.tar.xz",
      sha256 = "1c036c0d72e4b3d1fb5c94c88632add6f9d76f4d7c4d2ea793c12a9f19a3228c",
    } | Source,
    base,
    toolchain,
    gcc,
    make,
    pkgconf,
    glibc,
    # Terminal + line editing. Built --with-system-readline so gdb uses OUR
    # readline rather than its bundled copy — a bundled copy would be invisible
    # to pkgscan, which is the same reasoning applied to rizin's use_sys_* flags.
    ncurses,
    readline,
    # XML target descriptions and remote memory maps. Effectively required in
    # practice even though configure treats it as optional.
    expat,
    # Debug-info compression formats gdb reads directly from ELF sections.
    zlib,
    xz,
    zstd,
    # Expression arithmetic.
    gmp,
    mpfr,
    # LOAD-BEARING: gef is a Python extension and cannot load into a gdb built
    # without --with-python. See build.sh.
    python,
  ],
  runtime_deps = [
    bash,
    # `gcore` is a shell script with a `#!/usr/bin/env` shebang, so env must be
    # present at RUNTIME or the script is unrunnable. Caught by the
    # missing_runtime_deps checker rather than by us noticing.
    coreutils,
    ncurses,
    readline,
    expat,
    zlib,
    xz,
    zstd,
    gmp,
    mpfr,
    python,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    gdb = { glob = "usr/bin/gdb" } | OutputBin,
    gdb_add_index = { glob = "usr/bin/gdb-add-index" } | OutputBin,
    gcore = { glob = "usr/bin/gcore" } | OutputBin,
    gdbserver = { glob = "usr/bin/gdbserver" } | OutputBin,
    # gdb's Python runtime support files — the `python` directory it loads its
    # own pretty-printers and commands from.
    gdb_data = { glob = "usr/share/gdb/**" } | OutputData,
  },
  tests = {
    smoketest = standaloneTest "/bin/gdb --version",

    # PIN THE TWO PROPERTIES THE CONFIGURE FLAGS EXIST FOR. Both regress
    # SILENTLY: configure probes for Python and for target support, and if
    # either probe fails it prints a note and carries on to a successful build.
    # You would get a gdb that installs, runs, passes a --version smoketest, and
    # is useless for the thing it was packaged to do.
    capabilities =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # --with-python: gef is a Python extension. Without this gdb reports
          # "Python scripting is not supported in this copy of GDB" and gef
          # cannot load at all.
          ["/bin/bash", "-c", "gdb -batch -ex 'python print(\"py-ok\")' | grep -q py-ok"],
          # --enable-targets=all: a foreign architecture must be selectable, or
          # gdb cannot disassemble a binary emulated under qemu-user's gdbstub.
          # i386 is foreign on every arch we build for.
          ["/bin/bash", "-c", "gdb -batch -ex 'set architecture' 2>&1 | grep -q i386"],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'GnuProject,
        name = "gdb",
      },
    } | Attrs,
} | BuildSpec
