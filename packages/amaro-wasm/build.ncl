let { Attrs, BuildSpec, Local, Needs, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let wasm-bindgen-cli = import "../wasm-bindgen-cli/build.ncl" in

# The amaro versions node (1.1.11) and node-lts (1.1.10) bundle. Each tag vendors the swc tree its
# TypeScript stripper is built from (deps/swc, with Cargo.lock).
let amaro_versions = ["1.1.10", "1.1.11"] in
# the rust package's version; build.sh fails if rustc is not this version
let rust_version = "1.99.0" in
{
  name = "amaro-wasm",
  # amaro is node's built-in TypeScript type stripper (`node x.ts`): swc's
  # binding_typescript_wasm, compiled to wasm32-unknown-unknown and run through wasm-bindgen,
  # base64-inlined into amaro's dist/index.js. This rebuilds that module from the vendored swc
  # source, the way amaro's tools/build-wasm.js does in its container (cargo --release with fat LTO
  # and opt-level z, wasm-bindgen --target nodejs, no wasm-opt), so node and node-lts can splice it
  # over the shipped blob.
  #
  # The rust package ships no wasm32 std and no rust-lld: std is built with -Zbuild-std from the
  # rustc source tarball of the same version, and llvm's wasm-ld links.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nodejs/amaro/archive/refs/tags/v1.1.10.tar.gz",
      sha256 = "fdb7f889ab6a52f0477d40cecb7d2248c699793c36359ea8c3f4bed031da7fd6",
      extract = false,
    } | Source,
    {
      url = "https://github.com/nodejs/amaro/archive/refs/tags/v1.1.11.tar.gz",
      sha256 = "f65b4e8ae9ab519e8db1824377eb621d7fce66e21ae1020621d8f54b6ed774fa",
      extract = false,
    } | Source,
    {
      # the rust package's own source
      url = "gs://minimal-staging-archives/rustc-%{rust_version}-src.tar.xz",
      sha256 = "cc41916a8c84f5d9ec4f55561b44e39f43b647b133f8a6f51be9ea13c83f7036",
      extract = false,
    } | Source,
    base,
    llvm,
    rust,
    toolchain,
    wasm-bindgen-cli,
  ],

  # cargo fetches the crates in swc's Cargo.lock and std's library/Cargo.lock (--locked).
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    amaro_versions = std.string.join " " amaro_versions,
    rust_version = rust_version,
  },

  outputs = {
    wasm = { glob = "usr/share/amaro-wasm/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = "1.1.11",
      license_spdx = "MIT AND Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nodejs",
        repo = "amaro",
      },
    } | Attrs,

  tests = {
    modules =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "for v in 1.1.10 1.1.11; do head -c4 /usr/share/amaro-wasm/$v/wasm_bg.wasm | od -An -c | grep -q 'a   s   m' || exit 1; done"],
        ],
      } | Test,
  },
} | BuildSpec
