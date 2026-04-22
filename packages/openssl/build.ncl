let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.6.2" in
{
  name = "openssl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssl/openssl/openssl-%{version}.tar.gz",
      sha256 = "bc7dc809d1842e4a9c190765d83fb6a88084c75c8b04b4c3c304a929d33a5108",
      extract = true,
      strip_prefix = "openssl-openssl-%{version}",
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
    c_rehash = { glob = "usr/bin/c_rehash", allow_missing_interpreter = true } | OutputBin,

    libcrypto = { glob = "usr/lib/libcrypto.so*" } | OutputLib,
    libssl = { glob = "usr/lib/libssl.so*" } | OutputLib,

    engines-3 = { glob = "usr/lib/engines-3/*.so*" } | OutputLib,
    ossl-modules = { glob = "usr/lib/engines-3/*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/OpenSSL/*.cmake" } | OutputData,

    includes = { glob = "usr/include/openssl/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    etc = { glob = "etc/ssl/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "openssl",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openssl",
        repo = "openssl",
      },
    } | Attrs,
} | BuildSpec
