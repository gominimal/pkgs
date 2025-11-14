let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let curl = import "../curl/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let python = import "../python/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let toolchain-gnullvm = import "../toolchain-gnullvm/build.ncl" in
let resolver-quad8 = import "../resolver-quad8/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "1.91.1" in
{
  name = "rust",
  inputs = [
    { file = "bootstrap.toml" } | Local,
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/rustc-%{version}-src.tar.xz",
      sha256 = "66401bb815e236cc6b2aacbbe23b61b286c1fe27a67902e7c0222cfe77b3dbab",
      extract = true,
      strip_prefix = "rustc-%{version}-src",
    } | Source,
    base,
    cmake,
    curl,
    pkgconf,
    python,
    toolchain-gnullvm,
  ],
  runtime_deps = [
    libffi,
    llvm,
    openssl,
    sqlite,
    resolver-quad8,
    gcc, # Needs libstdc++.so.6 and libgcc_s.so.1, but also a lot of crates need GCC
  ],

  cmd = "./build.sh",
  outputs = {
    usr = { glob = "usr/**/*" } | OutputLib,
  },

  attrs = {
    upstream_version = version,
    env_state_wiring = {
        env_var = "CARGO_HOME",
        prefix = ".cargo",
    },
  },
} | BuildSpec
