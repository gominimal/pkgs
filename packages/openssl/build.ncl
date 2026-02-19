let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.6.1" in
{
  name = "openssl",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssl/openssl/openssl-%{version}.tar.gz",
      sha256 = "f68e6e3a19902c0487d684a4122d4127bc649b4f8f51c15324bb36e0e4dc0bfa",
      extract = true,
      strip_prefix = "openssl-openssl-%{version}",
    } | Source,
    base,
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
    c_rehash = { glob = "usr/bin/c_rehash" } | OutputBin,

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
