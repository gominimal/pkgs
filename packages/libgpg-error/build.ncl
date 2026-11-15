# Imported from Wolfi `libgpg-error` by `pkgmgr import wolfi` (autotools build).
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
let gettext = import "../gettext/build.ncl" in
let version = "1.61" in
{
  name = "libgpg-error",
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
    gettext,
    {
      url = "https://github.com/gpg/libgpg-error/archive/refs/tags/libgpg-error-%{version}.tar.gz",
      sha256 = "d856f3582d31fd754afe876abf6f269e4f2f4e75c7ca2047971fb6e9b1d6e552",
      extract = true,
      strip_prefix = "libgpg-error-libgpg-error-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/{gpg-error,yat2m}" } | OutputBin,
    # A /bin/sh script that consumers' configure runs inside their own build,
    # which always has a shell; nothing runs it from this package's closure.
    config = { glob = "usr/bin/gpgrt-config", allow_missing_interpreter = true } | OutputBin,
    libs = { glob = "usr/lib/libgpg-error.{a,so*}" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    # aclocal macros (AM_PATH_*) for consumers that regenerate configure.
    share = { glob = "usr/share/**" } | OutputData,
  },
  # gpg-error, yat2m and libgpg-error.so.0 link only libc (and the library itself).
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "gpg", repo = "libgpg-error" },
      license_spdx = "GPL-2.0-or-later AND LGPL-2.1-or-later",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, pkgconf],
        cmds = [
          # TODO: REVIEWER — ported from the Wolfi test block; verify each
          # against minimal's toolchain (bins on PATH, flags supported).
          ["/bin/bash", "-c", "set -e\ngpg-error --version\nyat2m --version\ngpg-error --help\nyat2m --help"],
          ["/bin/bash", "-c", "tee test.c <<'EOF'\n#include <gpg-error.h>\n#include <stdio.h>\nint main() {\n    gpg_error_t err = gpg_err_make(GPG_ERR_SOURCE_USER_1, GPG_ERR_GENERAL);\n    const char *msg = gpg_strerror(err);\n    printf(\"Error message: %s\\n\", msg);\n    return (msg != NULL) ? 0 : 1;\n}\nEOF\n\ngcc $(pkg-config --cflags gpg-error) test.c -o test $(pkg-config --libs gpg-error)\n./test"],
          ["/bin/bash", "-c", "# gpg-error translates numeric error codes to human-readable strings\noutput=$(gpg-error 1)\necho \"$output\" | grep -i \"General error\"\n\n# Test with a known GPG error source prefix\noutput=$(gpg-error 0)\necho \"$output\" | grep -i \"success\""],
          ["/bin/bash", "-c", "# Create a minimal yat2m input file\ntee /tmp/test.texi <<'EOF'\n@manpage test.1\n@mansect 1\n@ifset manverb\n.TH TEST 1\n@end ifset\n\n@mansect name\n@ifset manverb\ntest \\- a test man page\n@end ifset\n\n@mansect description\nThis is a test description.\nEOF\n\n# Run yat2m and verify it produces output\nyat2m -I /tmp/test.texi -o /tmp/test.1 || yat2m /tmp/test.texi\n# Verify yat2m ran without error (the tool processed the input)\necho \"yat2m executed successfully\""],
          ["/bin/bash", "-c", "gpgrt-config --version\ngpgrt-config --help"],
          ["/bin/bash", "-c", "tee test.c <<'EOF'\n#include <gpg-error.h>\n#include <stdio.h>\nint main() {\n    gpg_error_t err = gpg_err_make(GPG_ERR_SOURCE_USER_1, GPG_ERR_GENERAL);\n    const char *msg = gpg_strerror(err);\n    printf(\"Error message: %s\\n\", msg);\n    return (msg != NULL) ? 0 : 1;\n}\nEOF\n\ngcc $(pkg-config --cflags gpg-error) test.c -o test $(pkg-config --libs gpg-error)\n./test"],
        ],
      } | Test,
  },
} | BuildSpec
