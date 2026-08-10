let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let llvm = import "../llvm/build.ncl" in

# bindgen — generates Rust FFI bindings from C/C++ headers by driving
# libclang. Packaged as a chromium-from-source build prerequisite
# (pkgmgr-rs#681): chromium's gn wires `rust_bindgen_root` and the
# official tarball's bundled bindgen is an x86-64-only prebuilt, so the
# arm64 build needs a system one. 0.72.1 is exactly Gentoo's floor for
# chromium 151.
#
# libclang is a RUNTIME dependency: bindgen dlopens libclang.so to parse
# headers, and needs clang's resource headers (usr/lib/clang/<ver>/) for
# builtin includes — both from the llvm package.
let version = "0.72.1" in
{
  name = "bindgen",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/rust-lang/rust-bindgen/v%{version}.tar.gz",
      sha256 = "4ffb17061b2d71f19c5062d2e17e64107248f484f9775c0b7d30a16a8238dfd1",
      extract = true,
      strip_prefix = "rust-bindgen-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    subsetOf llvm ["libclang", "libs_clang"],
  ],

  cmd = "./build.sh",

  outputs = {
    bindgen = { glob = "usr/bin/bindgen" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rust-lang",
        repo = "rust-bindgen",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/bindgen --version",
  },
} | BuildSpec
