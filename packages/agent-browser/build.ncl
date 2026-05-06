let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let node = import "../node/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in

let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Why playwright-chromium and not chrome-for-testing:
#
# Upstream agent-browser is built around Chrome for Testing (Google's official
# automation channel), and that would be the natural pkg to depend on here.
# Problem: as of 2026-05-06 Google does not publish a linux-arm64 CfT build —
# the JSON manifest at googlechromelabs.github.io/chrome-for-testing/ has only
# linux64, mac-arm64, mac-x64, win32, win64. The Chromium team announced ARM64
# Linux Chrome for Q2 2026 (we're mid-Q2 now) but the CfT publishing pipeline
# hasn't shipped arm64 zips yet.
#
# Playwright builds and self-hosts a linux-arm64 chromium of its own (its CDN
# redirects x86_64 requests to Google's CfT bucket but routes arm64 requests
# to playwright.download.prss.microsoft.com). So `playwright-chromium` is the
# only pinnable chromium source that works on both arches today.
#
# When CfT starts publishing linux-arm64, flip this back to chrome-for-testing
# (per-arch dispatch, or unconditional once the lag is gone). Tracked in the
# Notion follow-up sub-task on the chromium pkg-extract ticket.
#
# playwright-chromium also brings the full chromium system-lib closure
# (alsa-lib, cairo, cups, nss, mesa, the X11 stack, eudev, liberation-fonts,
# etc.) transitively, so we only declare the pkg directly.
let playwright-chromium = import "../playwright-chromium/build.ncl" in

let version = "0.15.1" in
{
  name = "agent-browser",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vercel-labs/agent-browser/v%{version}.tar.gz",
      sha256 = "c30724a5fba1beb217ca5ce5ce9eee43b596dc72efe9ac29adb9af717795b6c9",
      extract = true,
      strip_prefix = "agent-browser-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
    rust,
    node,
    pnpm,
  ],
  runtime_deps = [
    bash,
    node,
    glibc,
    playwright-chromium,
  ],

  cmd = "./build.sh",

  outputs = {
    bin = { glob = "usr/bin/agent-browser" } | OutputBin,
    libexec = { glob = "usr/libexec/agent-browser/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel-labs",
        repo = "agent-browser",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/agent-browser --version",
  },
} | BuildSpec
