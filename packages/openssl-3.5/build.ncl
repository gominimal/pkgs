let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# OpenSSL 3.5 LTS (supported to 2030-04-08) as a COMPAT library beside packages/openssl
# (4.x). It is for code that cannot use 4.x and needs the libssl.so.3 / libcrypto.so.3
# sonames:
#   - rustc-1.98.1's stage0: both sealed rustc-1.97.1 bedrock tarballs (amd64, arm64) ship
#     a cargo with DT_NEEDED libssl.so.3 + libcrypto.so.3.
#   - actions-runner: its bundled .NET 8 runtime dlopens libssl.so.3. Only .NET 10 got the
#     OpenSSL 4 loader (dotnet/runtime#135534, merged 2026-10-10).
#   - sources that do not build against 4.x: foundationdb 7.3 (C++ X509 const errors;
#     upstream is itself moving to a pinned 3.5, apple/foundationdb#14348).
#
# Layout, chosen so nothing collides with packages/openssl in one sandbox (two packages
# installing one path is decided silently by spec hash):
#   /usr/lib/libssl.so.3, /usr/lib/libcrypto.so.3          runtime sonames, default loader path
#   /usr/lib/openssl-3.5/include, lib/pkgconfig, lib/cmake  dev tree, opt-in
#   /usr/lib/openssl-3.5/lib/lib{ssl,crypto}.so -> ../../lib*.so.3
#   /usr/lib/openssl-3.5/lib/{ossl-modules,engines-3}       compiled-in MODULESDIR / ENGINESDIR
# No /usr/bin/openssl, /usr/include/openssl, /usr/lib/pkgconfig/*.pc or /etc/ssl files:
# those belong to packages/openssl. OPENSSLDIR is still /etc/ssl, so 3.5 reads the same
# openssl.cnf and the CA store packages/ca-certificates fills.
#
# Symbol versions differ (OPENSSL_3.0.0.. here, OPENSSL_4.0.0 in 4.x), so a process that
# loads both (bedrock cargo: libssl.so.3 directly, libssh2/libcurl -> libssl.so.4) binds
# each reference to its own library.
#
# To build against it: PKG_CONFIG_PATH=/usr/lib/openssl-3.5/lib/pkgconfig, or
# OPENSSL_ROOT_DIR=/usr/lib/openssl-3.5 (CMake), or OPENSSL_DIR=/usr/lib/openssl-3.5
# (openssl-sys).
#
# The name carries the series, so pkgmgr's name pin keeps it on 3.5.x.
let version = "3.5.9" in
{
  name = "openssl-3.5",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssl/openssl/openssl-%{version}.tar.gz",
      # = openssl-3.5.9.tar.gz.sha256 on the GitHub release (release tarball, top dir openssl-3.5.9/).
      sha256 = "603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a",
      extract = true,
      strip_prefix = "openssl-%{version}",
    } | Source,
    base-bootstrap,
    perl,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libcrypto = { glob = "usr/lib/libcrypto.so.3" } | OutputLib,
    libssl = { glob = "usr/lib/libssl.so.3" } | OutputLib,

    dev_links = { glob = "usr/lib/openssl-3.5/lib/lib*.so" } | OutputLib,
    ossl-modules = { glob = "usr/lib/openssl-3.5/lib/ossl-modules/*.so" } | OutputLib,
    engines-3 = { glob = "usr/lib/openssl-3.5/lib/engines-3/*.so" } | OutputLib,

    includes = { glob = "usr/lib/openssl-3.5/include/openssl/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/openssl-3.5/lib/pkgconfig/**" } | OutputData,
    cmake_data = { glob = "usr/lib/openssl-3.5/lib/cmake/OpenSSL/*.cmake" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "openssl",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openssl",
        repo = "openssl",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/sh", "-c", "test -e /usr/lib/libssl.so.3 && test -e /usr/lib/libcrypto.so.3"],
          ["/bin/sh", "-c", "test \"$(readlink -f /usr/lib/openssl-3.5/lib/libssl.so)\" = /usr/lib/libssl.so.3"],
          ["/bin/sh", "-c", "grep -q '^Version: 3[.]5[.]' /usr/lib/openssl-3.5/lib/pkgconfig/openssl.pc"],
        ],
      } | Test,
  },
} | BuildSpec
