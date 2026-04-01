let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let libvips = import "../libvips/build.ncl" in
let make = import "../make/build.ncl" in
let node = import "../node/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "16.2.2" in
{
  name = "next",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vercel/next.js/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "1f346a1c543180b2ad1a22664d02781b85e0f2a001e18a30c2d6381aa9672e48",
      extract = true,
      strip_prefix = "next.js-%{version}",
    } | Source,
    base,
    make,
    node,
    pkgconf,
    pnpm,
    python,
    toolchain,
  ],
  runtime_deps = [
    coreutils,
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel",
        repo = "next.js",
      },
    } | Attrs,
} | BuildSpec
