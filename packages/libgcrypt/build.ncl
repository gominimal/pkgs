# Imported from Wolfi `libgcrypt` by `pkgmgr import wolfi` (autotools build).
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
let version = "1.12.4" in
{
  name = "libgcrypt",
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
    {
      url = "https://github.com/gpg/libgcrypt/archive/refs/tags/libgcrypt-%{version}.tar.gz",
      sha256 = "236c50d0d07743cf57ceafe8e044dfd5d8ff38e4dc04a4313814a97d989dfcc3",
      extract = true,
      strip_prefix = "libgcrypt-libgcrypt-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    # Discovery catch-all — rerun with `--from-build <artifact>` to refine
    # into precise, typed outputs (bins/libs/includes/…).
    everything = { glob = "usr/**", allow_executable = true } | OutputData,
  },
  # TODO: REVIEWER — trim to the shared libraries the binary actually links (ldd the build).
  runtime_deps = [glibc, libgpg-error, libtool],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "gpg", repo = "libgcrypt" },
      # This package's output glob is usr/**, so it ships the library, the
      # tools (dumpsexp, hmac256, mpicalc) and the manual, and the expression
      # has to cover all three. From upstream 1.12.4:
      #   AUTHORS:  "License (library): LGPLv2.1+"
      #             "License (manual and tools): GPLv2+"
      #   LICENSES: a BSD_3Clause section covering Intel's SHA assembly
      #             (cipher/sha{256,512}-*-amd64.S, sha512-ssse3-i386.c)
      # The other LICENSES sections are deliberately NOT listed: "X License"
      # covers install.sh, a build script that is never installed; "Public
      # domain" needs no grant; "OCB license 1" is a patent grant, not a
      # copyright licence.
      license_spdx = "LGPL-2.1-or-later AND GPL-2.0-or-later AND BSD-3-Clause",
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, pkgconf],
        cmds = [
          # TODO: REVIEWER — ported from the Wolfi test block; verify each
          # against minimal's toolchain (bins on PATH, flags supported).
          ["/bin/bash", "-c", "dumpsexp --version\ndumpsexp --help\nhmac256 --version\nhmac256 --help\nmpicalc --version\nmpicalc --help"],
          ["/bin/bash", "-c", "set -euo pipefail\n\ntee test.c <<'EOF'\n#include <gcrypt.h>\n#include <stdio.h>\nint main() {\n    const char *ver = gcry_check_version(NULL);\n    if (ver == NULL) {\n        fprintf(stderr, \"FAIL: gcry_check_version returned NULL\\n\");\n        return 1;\n    }\n    printf(\"libgcrypt version: %s\\n\", ver);\n    return 0;\n}\nEOF\n\ngcc $(pkg-config --cflags libgcrypt) test.c -o test $(pkg-config --libs libgcrypt)\n./test"],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Compute HMAC-SHA256 of a known string with a known key\nresult=$(echo -n \"test message\" | hmac256 \"mysecretkey\")\necho \"hmac256 output: $result\"\n\n# Verify output is a hex string (64 hex chars for SHA-256)\necho \"$result\" | grep -E '^[0-9a-fA-F]{64}'"],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Create a sample S-expression and parse it with dumpsexp\nprintf '(3:foo3:bar)' > /tmp/test.sexp\noutput=$(dumpsexp /tmp/test.sexp)\necho \"dumpsexp output: $output\"\n\n# Verify dumpsexp parsed the S-expression (should contain foo and bar)\necho \"$output\" | grep -F \"foo\"\necho \"$output\" | grep -F \"bar\""],
          ["/bin/bash", "-c", "set -euo pipefail\n\n# Test basic arithmetic with mpicalc\n# mpicalc uses RPN (reverse polish notation)\nresult=$(echo -e \"2\\n3\\n+\\np\" | mpicalc)\necho \"mpicalc output: $result\"\n\n# Verify the result contains 5 (2+3=5, displayed as hex 05)\necho \"$result\" | grep -F \"05\""],
          ["/bin/bash", "-c", "set -euo pipefail\nlibgcrypt-config --version\nlibgcrypt-config --cflags\nlibgcrypt-config --libs"],
        ],
      } | Test,
  },
} | BuildSpec
