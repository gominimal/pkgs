# Imported from Wolfi `libassuan` by `pkgmgr import wolfi` (autotools build).
# TODO: REVIEWER — verify the build.sh opts. (outputs and runtime_deps are
# taken from the built install tree: its file list and each ELF's DT_NEEDED.)
let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libgpg-error = import "../libgpg-error/build.ncl" in
let readline = import "../readline/build.ncl" in
let version = "3.0.2" in
{
  name = "libassuan",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    autoconf,
    automake,
    libtool,
    m4,
    make,
    pkgconf,
    toolchain,
    glibc,
    libgpg-error,
    readline,
    {
      url = "https://github.com/gpg/libassuan/archive/refs/tags/libassuan-%{version}.tar.gz",
      sha256 = "dfd4e6b85de83c7b8096c6d79b914501611f56a21c3db92f63352030d21e3d6f",
      extract = true,
      strip_prefix = "libassuan-libassuan-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libassuan.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    # aclocal macros (AM_PATH_*) for consumers that regenerate configure.
    share = { glob = "usr/share/**" } | OutputData,
  },
  # libassuan.so.9 links libgpg-error.so.0 and libc.
  runtime_deps = [glibc, libgpg-error],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "gpg", repo = "libassuan" },
      # Upstream 3.0.2 AUTHORS: "License (library): LGPLv2.1+" and
      # "License (manual): GPLv3+". What this package installs (read from the
      # built tree, both arches): libassuan.so.* and assuan.h (LGPLv2.1+ per
      # their notices), libassuan.pc, and aclocal/libassuan.m4, which upstream
      # tags "SPDX-License-Identifier: FSFULLR". No manual is installed, so
      # the GPLv3+ term does not apply.
      license_spdx = "LGPL-2.1-or-later AND FSFULLR",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, pkgconf],
        cmds = [
          # TODO: REVIEWER — ported from the Wolfi test block; verify each
          # against minimal's toolchain (bins on PATH, flags supported).
          ["/bin/bash", "-c", "tee test.c <<'EOF'\n#include <assuan.h>\nint main() {\n    const char *v = assuan_check_version(NULL);\n    return v == NULL ? 1 : 0;\n}\nEOF\n\ngcc $(pkg-config --cflags libassuan) test.c -o test $(pkg-config --libs libassuan)\n./test"],
        ],
      } | Test,
  },
} | BuildSpec
