let { Attrs, BuildSpec, Local, Needs, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let wasm-bindgen-cli = import "../wasm-bindgen-cli/build.ncl" in

# The amaro versions node and node-lts bundle, read from versions.ncl (the one place they are
# recorded): each distinct one, in versions.ncl's field order. Each tag vendors the swc tree the
# TypeScript stripper is built from (deps/swc, with Cargo.lock); build.sh builds every one.
let versions = import "versions.ncl" in
let amaro_versions =
  std.array.fold_left
    (fun acc v => if std.array.elem v acc then acc else acc @ [v])
    []
    (std.record.values versions.bundled)
in
let amaro = std.string.join " " amaro_versions in
# the rust package's version; build.sh fails if rustc is not this version
let rustc = "1.99.1" in
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
  build_deps =
    [{ file = "build.sh" } | Local]
    @ std.array.map
      (fun v =>
        {
          url = "https://github.com/nodejs/amaro/archive/refs/tags/v%{v}.tar.gz",
          sha256 = versions.tag_sha256."%{v}",
          extract = false,
        } | Source
      )
      amaro_versions
    @ [
      {
        # the rust package's own source
        url = "gs://minimal-staging-archives/rustc-%{rustc}-src.tar.xz",
        sha256 = "6451598a99e77f07571960f6b21d577399d3a30f33e80cbd2e3a4aae6535d265",
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
    amaro_versions = amaro,
    rust_version = rustc,
  },

  outputs = {
    wasm = { glob = "usr/share/amaro-wasm/**" } | OutputData,
  },

  attrs =
    {
      # node's entry (the current line) is the version pkgmgr checks upstream against.
      upstream_version = versions.bundled.node,
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
          ["/bin/bash", "-c", "for v in %{amaro}; do head -c4 /usr/share/amaro-wasm/$v/wasm_bg.wasm | od -An -c | grep -q 'a   s   m' || exit 1; done"],
        ],
      } | Test,
  },
} | BuildSpec
