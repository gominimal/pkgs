# Imported from Wolfi `libassuan` by `pkgmgr import wolfi` (autotools build).
# TODO: REVIEWER — verify deps/outputs/runtime_deps + the build.sh opts.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
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
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  # TODO: REVIEWER — trim to the shared libraries the binary actually links (ldd the build).
  runtime_deps = [glibc, autoconf, automake, libgpg-error, libtool, readline],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "gpg", repo = "libassuan" },
      license_spdx = "LGPL-2.1-or-later",
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
