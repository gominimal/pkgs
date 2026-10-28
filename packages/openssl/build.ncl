let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.1.0" in
{
  name = "openssl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssl/openssl/openssl-%{version}.tar.gz",
      # = openssl-4.1.0.tar.gz.sha256 on the GitHub release (release tarball, top dir openssl-4.1.0/).
      sha256 = "50c17baf54cb008f6ce42d50deb4b28050a1aad711636cabd4b241c7e90cc2fd",
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
    openssl = { glob = "usr/bin/openssl" } | OutputBin,
    # 4.0 removed the c_rehash script (use `openssl rehash`), and ENGINE support with it:
    # no engines-N directory is installed any more.

    libcrypto = { glob = "usr/lib/libcrypto.so*" } | OutputLib,
    libssl = { glob = "usr/lib/libssl.so*" } | OutputLib,

    # Providers (legacy.so). Through 3.6.5 this glob pointed at engines-3, so the legacy
    # provider was never shipped.
    ossl-modules = { glob = "usr/lib/ossl-modules/*.so" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/OpenSSL/*.cmake" } | OutputData,

    includes = { glob = "usr/include/openssl/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    etc = { glob = "etc/ssl/**/*" } | OutputData,
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
    smoketest = standaloneTest "/usr/bin/openssl version",

    # Pins the 4.x behaviour at TEST time, not only in build.sh (msample on #1140):
    # the .so.4 layout with no engines, the legacy provider (first shipped here)
    # and MD4 through it, and TLS 1.2 + 1.3 loopback handshakes that verify a
    # throwaway P-256 cert by IP SAN. Loopback needs no network.
    openssl4_behaviour =
      {
        class = 'Standalone,
        test_deps = [base-bootstrap, glibc],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -eu
              test -e /usr/lib/libssl.so.4 && test ! -e /usr/lib/engines-3
              openssl list -providers -provider legacy -provider default | grep -q legacy
              echo x | openssl dgst -md4 -provider legacy -provider default
              openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout k.pem -out c.pem -days 2 -subj /CN=localhost -addext subjectAltName=IP:127.0.0.1
              openssl s_server -accept 44330 -cert c.pem -key k.pem -www &
              srv=$!
              trap 'kill $srv 2>/dev/null || true' EXIT
              sleep 1
              echo | openssl s_client -connect 127.0.0.1:44330 -tls1_2 -CAfile c.pem -verify_return_error | grep -q 'Verify return code: 0'
              echo | openssl s_client -connect 127.0.0.1:44330 -tls1_3 -CAfile c.pem -verify_return_error | grep -q 'Verify return code: 0'
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
