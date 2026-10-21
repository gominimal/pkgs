let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glib = import "../glib/build.ncl" in
let libvips = import "../libvips/build.ncl" in
let make = import "../make/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let wasi-libc = import "../wasi-libc/build.ncl" in
let llhttp-wasm-rebuild = import "../llhttp-wasm-rebuild/build.ncl" in

# undici whose llhttp C rebuilds the wasm next bundles into its edge runtime.
# Forwarded to build.sh as MINIMAL_ARG_UNDICI.
let undici = "6.28.0" in

let version = "16.4.1" in
{
  name = "next",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vercel/next.js/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "aa5bc85844ca810037f2f0545c2c22a79222750d21baae1fe451dc0e0333b8ae",
      extract = true,
      strip_prefix = "next.js-%{version}",
    } | Source,
    {
      url = "gs://minimal-staging-archives/undici-%{undici}.tar.gz",
      sha256 = "555a14624f66628d8aa7fcd0691ab2371f3e4512c40358bb7320bfabbb6763ec",
    } | Source,
    llvm, # clang + wasm-ld for the llhttp wasm
    wasi-libc,
    llhttp-wasm-rebuild,
    base,
    glib,
    make,
    node-lts,
    pkgconf,
    pnpm,
    python,
    toolchain,
  ],
  runtime_deps = [
    coreutils,
    glib,
    libvips,
    subsetOf node-lts ["node"],
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
    include undici,
  },

  outputs = {
    next = { glob = "usr/bin/next" } | OutputBin,
    libexec = { glob = "usr/libexec/next/**", allow_executable = true } | OutputData,
  },

  tests = {
    cli =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "next --version | grep -q '16'"],
          ["/bin/bash", "-c", "next telemetry status | grep -q 'Status'"],
          ["/bin/bash", "-c", "node -e \"const c = require('/usr/libexec/next/lib/node_modules/next/dist/shared/lib/constants.js'); if (c.PHASE_PRODUCTION_BUILD !== 'phase-production-build') process.exit(1);\""],
        ],
      } | Test,
    sharp_uses_system_libvips =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "node -e \"const s = require('/usr/libexec/next/lib/node_modules/next/node_modules/sharp'); const v = s.versions; console.log('vips:', v.vips); if (!v.vips) { throw new Error('no vips version'); }\""],
          ["/bin/bash", "-c", "node -e \"const s = require('/usr/libexec/next/lib/node_modules/next/node_modules/sharp'); if (!s.versions.vips.startsWith('8.18')) { throw new Error('expected vips 8.18.x, got ' + s.versions.vips); }\""],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel",
        repo = "next.js",
      },
    } | Attrs,
} | BuildSpec
