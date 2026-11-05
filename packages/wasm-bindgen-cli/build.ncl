let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.130" in
{
  name = "wasm-bindgen-cli",
  # The wasm-bindgen post-processor: turns a rustc wasm32-unknown-unknown module plus its
  # wasm-bindgen custom sections into the final module and its JS glue. Only the `wasm-bindgen`
  # binary ships; its version must equal the wasm-bindgen crate locked by the code it processes.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://static.crates.io/crates/wasm-bindgen-cli/wasm-bindgen-cli-%{version}.crate",
      sha256 = "c37f6904387d19a319525c74af274c73912f3871c35555aa49f3ea64ebb2fc7a",
      # a .crate is a gzipped tar; build.sh unpacks it (Source extraction keys on the extension)
      extract = false,
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  # cargo fetches the crates in the published Cargo.lock (--locked) during the build.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/wasm-bindgen" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rustwasm",
        repo = "wasm-bindgen",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "wasm-bindgen --version | grep -qx 'wasm-bindgen %{version}'"],
        ],
      } | Test,
  },
} | BuildSpec
