let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let perl = import "../perl/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.6.3" in
{
  name = "openssl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/openssl/openssl/openssl-%{version}.tar.gz",
      sha256 = "c5524dd6bfaa8e8ff0f1be885c390d14f3ff0bd2de62a7311b65fcbb75cb7546",
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
      license_spdx = "Apache-2.0",
      repology_project = "openssl",
      source_provenance = {
        category = 'GithubRepo,
        owner = "openssl",
        repo = "openssl",
      },
    } | Attrs,
} | BuildSpec
