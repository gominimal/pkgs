let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glib = import "../glib/build.ncl" in
let libvips = import "../libvips/build.ncl" in
let make = import "../make/build.ncl" in
let node = import "../node/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "16.3.0" in
{
  name = "next",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vercel/next.js/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "9269716701c0aee3e8138530c01f11a22f5fc20c5dec0d3ce131b7e5741caa9b",
      extract = true,
      strip_prefix = "next.js-%{version}",
    } | Source,
    # #53 offline: next pins pnpm@9.6.0 (its lockfile is authored by it). The build
    # uses this EXACT pnpm + --frozen so it reads the 9.6.0-staged store correctly
    # (any pnpm 10.x re-resolves the 9.6.0 lockfile differently → store misses).
    # extract=false → hydrated to /build/pnpm-9.6.0.tgz; build.sh extracts + runs
    # `node .../pnpm.cjs` (self-contained bundled CLI).
    {
      url = "https://registry.npmjs.org/pnpm/-/pnpm-9.6.0.tgz",
      sha256 = "dae0f7e822c56b20979bb5965e3b73b8bdabb6b8b8ef121da6d857508599ca35",
      extract = false,
    } | Source,
    base,
    glib,
    make,
    node,
    pkgconf,
    pnpm,
    python,
    toolchain,
  ],
  runtime_deps = [
    coreutils,
    glib,
    libvips,
    node,
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
    libexec = { glob = "usr/lib/node_modules/next/**", allow_executable = true } | OutputData,
  },

  tests = {
    cli =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "next --version | grep -q '16'"],
          ["/bin/bash", "-c", "next telemetry status | grep -q 'Status'"],
          ["/bin/bash", "-c", "node -e \"const c = require('/usr/lib/node_modules/next/dist/shared/lib/constants.js'); if (c.PHASE_PRODUCTION_BUILD !== 'phase-production-build') process.exit(1);\""],
        ],
      } | Test,
    sharp_uses_system_libvips =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "node -e \"const s = require('/usr/lib/node_modules/next/node_modules/sharp'); const v = s.versions; console.log('vips:', v.vips); if (!v.vips) { throw new Error('no vips version'); }\""],
          ["/bin/bash", "-c", "node -e \"const s = require('/usr/lib/node_modules/next/node_modules/sharp'); if (!s.versions.vips.startsWith('8.18')) { throw new Error('expected vips 8.18.x, got ' + s.versions.vips); }\""],
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
