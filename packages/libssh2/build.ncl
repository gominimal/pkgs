let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let patch = import "../patch/build.ncl" in

# libssh2's last release is 1.11.1 (2024-10-16). Ten CVEs have been fixed
# upstream SINCE it — one CRITICAL, seven HIGH, one MEDIUM — and there is no
# newer release to move to. Repology confirms the whole ecosystem sits on
# 1.11.1: Arch, Fedora rawhide, Debian sid, Alpine edge, Homebrew, Nix.
#
# The industry answer is to stay on the released tarball and carry the upstream
# commits as patches; Debian ships exactly this as 1.11.1-6. Each file below is
# the verbatim upstream commit, and its `From <sha>` header matches the fix
# commit the corresponding advisory names.
#
# Pinning to a master commit was the alternative and is worse: same fixes, plus
# ~199 commits of unreleased drift and master's default change disabling SHA1
# hostkey methods.
let version = "1.11.1" in
{
  name = "libssh2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libssh2/libssh2/archive/refs/tags/libssh2-%{version}.tar.gz",
      sha256 = "82b35c61c78b475647bdc981a183c5b5ab0d979e1caee94186e8f9150f2b0d0d",
      extract = true,
      strip_prefix = "libssh2-libssh2-%{version}",
    } | Source,
    # Security backports, listed in the order build.sh applies them. That order
    # is Debian's series order and is load-bearing: 66032/15661 both touch
    # src/sftp.c, 55200/66035 both touch src/transport.c, and 66034/58050/58051
    # all touch src/publickey.c.
    { file = "CVE-2026-7598.patch" } | Local,
    { file = "CVE-2025-15661.patch" } | Local,
    { file = "CVE-2026-55199.patch" } | Local,
    { file = "CVE-2026-55200.patch" } | Local,
    # NOT a CVE fix — a PREREQUISITE. CVE-2025-15661's sftp.c hunk calls
    # `LIBSSH2_UNCONST()`, a macro that does not exist in 1.11.1; it arrived
    # later in upstream 606c102e. Without it the tree patches cleanly and then
    # fails to COMPILE (`implicit declaration of function 'LIBSSH2_UNCONST'`).
    # Debian carries it at this same position for the same reason.
    { file = "libssh-unconst-backport.patch" } | Local,
    { file = "CVE-2026-66032.patch" } | Local,
    { file = "CVE-2026-66033.patch" } | Local,
    { file = "CVE-2026-66034.patch" } | Local,
    { file = "CVE-2026-66035.patch" } | Local,
    { file = "CVE-2026-58050.patch" } | Local,
    { file = "CVE-2026-58051.patch" } | Local,
    base,
    cmake,
    make,
    toolchain,
    pkgconf,
    patch,
    openssl,
    zlib,
  ],
  runtime_deps = [
    glibc,
    openssl,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libssh2.so*" } | OutputLib,
    includes = { glob = "usr/include/libssh2*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libssh2.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/libssh2/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      repology_project = "libssh2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "libssh2",
        repo = "libssh2",
      },
    } | Attrs,

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "echo '#include <libssh2.h>\n#include <stdio.h>\nint main() { printf(\"%s\\n\", libssh2_version(0)); return 0; }' > test.c"],
          ["/bin/gcc", "test.c", "-lssh2", "-o", "test"],
          ["/bin/bash", "-c", "./test | grep -q '^1\\.'"],
        ],
      } | Test,
  },
} | BuildSpec
