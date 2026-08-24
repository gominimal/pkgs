let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Binaryen tags its releases version_<N>; the directory and the tag both use
# that form, so the bare number is kept separate from the tag it builds.
let version = "124" in
{
  name = "binaryen",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/WebAssembly/binaryen/archive/refs/tags/version_%{version}.tar.gz",
      sha256 = "b8d06af81a8c2bb27c34d1f9e3cf7c621f93fc901f896809e0490f3586a63ca4",
      extract = true,
      strip_prefix = "binaryen-version_%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/libbinaryen.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "WebAssembly",
        repo = "binaryen",
      },
    } | Attrs,

  tests = {
    # The six tools emscripten drives directly -- see emscripten's
    # docs/packaging.md. If a future bump drops or renames one, this catches it
    # here rather than part-way through an emcc run.
    emscripten_tools =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "set -eu; for t in wasm-opt wasm-emscripten-finalize wasm-dis wasm-as wasm2js wasm-metadce; do command -v $t >/dev/null; done"],
        ],
      } | Test,

    roundtrip =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "printf '(module (func $$f (result i32) (i32.const 42)) (export \"f\" (func $$f)))' > m.wat"],
          ["/bin/bash", "-c", "wasm-as m.wat -o m.wasm && wasm-opt -O3 m.wasm -o m.opt.wasm && wasm-dis m.opt.wasm | grep -q 'i32.const 42'"],
        ],
      } | Test,
  },
} | BuildSpec
