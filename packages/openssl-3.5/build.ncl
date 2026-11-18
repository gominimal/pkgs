let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
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
# The name carries the series, so pkgmgr's name pin keeps it on 3.5.x: the
# `openssl-3.5` entry in pkgmgr-rs data/series_pins.toml (gominimal/pkgmgr-rs#1140,
# merged 2026-10-28, deployed in the runner/service images since 95e00f8). It is
# load-bearing: Repology's `openssl` project has a single newest (4.x) and marks
# every 3.5.x as legacy/outdated, so without the pin 3.5.9 would read as behind.
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
    # Use the libraries the way both kinds of consumer do, with no packages/openssl (4.x)
    # in the sandbox to stand in for them:
    #   1. build against the opt-in dev tree (-I/-L /usr/lib/openssl-3.5, as rustc stage0 /
    #      foundationdb would) and check runtime == headers == the pinned version:
    #      OpenSSL_version(OPENSSL_VERSION_STRING) returns OPENSSL_VERSION_STR (crypto/
    #      cversion.c:89-90), "MAJOR.MINOR.PATCH" from VERSION.dat; OpenSSL_version_num()
    #      is 0xMNN00PP0 (include/openssl/opensslv.h.in:113-118), so >> 20 is 0x305 for 3.5.
    #      Then do real work: SSL_CTX_new(TLS_method()) and SHA-256("abc") against the
    #      FIPS 180-2 vector.
    #   2. dlopen("libssl.so.3") by soname with nothing linked, as .NET 8 does, and read
    #      the version through it (OpenSSL_version_num lives in libcrypto, reached as
    #      libssl's DT_NEEDED).
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              gcc -I/usr/lib/openssl-3.5/include -x c - -o linked -L/usr/lib/openssl-3.5/lib -lssl -lcrypto <<'EOF'
              #include <stdio.h>
              #include <string.h>
              #include <openssl/crypto.h>
              #include <openssl/evp.h>
              #include <openssl/opensslv.h>
              #include <openssl/ssl.h>
              int main(void) {
                const char *v = OpenSSL_version(OPENSSL_VERSION_STRING);
                unsigned long n = OpenSSL_version_num();
                printf("runtime %s (0x%08lx), headers %s (0x%08lx), pinned %%{version}\n",
                       v, n, OPENSSL_VERSION_STR, (unsigned long)OPENSSL_VERSION_NUMBER);
                if (strcmp(v, "%%{version}") != 0) return 1;
                if (n != (unsigned long)OPENSSL_VERSION_NUMBER || (n >> 20) != 0x305) return 1;

                SSL_CTX *ctx = SSL_CTX_new(TLS_method());
                printf("SSL_CTX_new(TLS_method()) = %s\n", ctx ? "ok" : "NULL");
                if (ctx == NULL) return 1;
                SSL_CTX_free(ctx);

                static const unsigned char want[32] = {
                  0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea, 0x41, 0x41, 0x40, 0xde,
                  0x5d, 0xae, 0x22, 0x23, 0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
                  0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad};
                unsigned char md[EVP_MAX_MD_SIZE];
                unsigned int len = 0;
                int ok = EVP_Digest("abc", 3, md, &len, EVP_sha256(), NULL);
                printf("EVP_Digest(sha256, \"abc\") ok=%d len=%u match=%d\n", ok, len,
                       len == 32 && memcmp(md, want, 32) == 0);
                if (!ok || len != 32 || memcmp(md, want, 32) != 0) return 1;
                puts("OK");
                return 0;
              }
              EOF
              ./linked

              gcc -x c - -o dl <<'EOF'
              #include <dlfcn.h>
              #include <stdio.h>
              int main(void) {
                void *h = dlopen("libssl.so.3", RTLD_NOW);
                if (h == NULL) { printf("dlopen(libssl.so.3): %s\n", dlerror()); return 1; }
                unsigned long (*num)(void) = (unsigned long (*)(void))dlsym(h, "OpenSSL_version_num");
                if (num == NULL) { printf("dlsym(OpenSSL_version_num): %s\n", dlerror()); return 1; }
                unsigned long n = num();
                printf("dlopen(libssl.so.3) -> OpenSSL_version_num() = 0x%08lx\n", n);
                if ((n >> 20) != 0x305) return 1;
                puts("OK");
                return 0;
              }
              EOF
              ./dl
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
