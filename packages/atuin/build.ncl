let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
# atuin 18.19.0 pulls native-tls: reqwest 0.13.4 takes its default-tls
# feature, and sqlx-core / tokio-tungstenite pull it too, so openssl-sys
# 0.9.117 now has to find a system OpenSSL via pkg-config. 18.17.1 had
# NEITHER crate in its Cargo.lock (0 -> 1 for both, verified against the two
# lockfiles), which is why this bump broke a build that had been fine.
let pkgconf = import "../pkgconf/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "18.19.0" in
{
  name = "atuin",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/atuinsh/atuin/v%{version}.tar.gz",
      sha256 = "fdb8268cdd5b13105db79e821f06c1c6624e0c5aee46befb0491e39af42fd4e6",
      extract = true,
      strip_prefix = "atuin-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    pkgconf,
    openssl,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    # The native-tls switch makes this a RUNTIME dep too, not just a build
    # one: the binary dynamically links libssl.so.3 + libcrypto.so.3.
    # The native-tls switch makes openssl a RUNTIME dep too, not just a build
    # one: the binary dynamically links libssl.so.3 + libcrypto.so.3. The
    # `missing runtime_deps` checker caught it — without this the package
    # builds clean and the shipped binary cannot start.
    openssl,
  ],

  cmd = "./build.sh",

  outputs = {
    atuin = { glob = "usr/bin/atuin" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "atuinsh",
        repo = "atuin",
      },
      build_cost_multiple = 3,
    } | Attrs,
} | BuildSpec
