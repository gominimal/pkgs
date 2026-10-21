let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
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

let version = "16.4.1" in
# The native SWC compiler Next loads at build/dev time. Upstream publishes it as a
# per-platform npm package (`@next/swc-linux-<arch>-gnu`) that `next` lists as an
# optionalDependency; the source build above does not produce it. Without it, every
# `next build` tries to download one into next's own tree, which is read-only here.
# Bump these alongside `version`: the binary must match next exactly.
let swc_amd64_sha256 = "78a7aa9334cfcb3b15ae3bdd19944aa6d7754639dc534fb0123a3d8fd4f00f47" in
let swc_arm64_sha256 = "ea6ca74538e44799986dbea7ae0b7142b37abf5d6b16fcf34566221c3e7b86ea" in
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
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://registry.npmjs.org/@next/swc-linux-x64-gnu/-/swc-linux-x64-gnu-%{version}.tgz",
          sha256 = swc_amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://registry.npmjs.org/@next/swc-linux-arm64-gnu/-/swc-linux-arm64-gnu-%{version}.tgz",
          sha256 = swc_arm64_sha256,
        } | Source,
    } target,
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
