let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let unzip = import "../unzip/build.ncl" in

let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let alsa-lib = import "../alsa-lib/build.ncl" in
let cairo = import "../cairo/build.ncl" in
let cups = import "../cups/build.ncl" in
let dbus = import "../dbus/build.ncl" in
let expat = import "../expat/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let glib = import "../glib/build.ncl" in
let harfbuzz = import "../harfbuzz/build.ncl" in
let libdrm = import "../libdrm/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let libxcb = import "../libxcb/build.ncl" in
let libxcomposite = import "../libxcomposite/build.ncl" in
let libxdamage = import "../libxdamage/build.ncl" in
let libxext = import "../libxext/build.ncl" in
let libxfixes = import "../libxfixes/build.ncl" in
let libxkbcommon = import "../libxkbcommon/build.ncl" in
let libxrandr = import "../libxrandr/build.ncl" in
let libxrender = import "../libxrender/build.ncl" in
let libxshmfence = import "../libxshmfence/build.ncl" in
let libxtst = import "../libxtst/build.ncl" in
let mesa = import "../mesa/build.ncl" in
let nss = import "../nss/build.ncl" in
let nspr = import "../nspr/build.ncl" in
let pango = import "../pango/build.ncl" in
let atk = import "../atk/build.ncl" in
let at-spi2-core = import "../at-spi2-core/build.ncl" in
let eudev = import "../eudev/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in

# Prebuilt full chromium browser (headed mode), named with the
# Gentoo/AUR `-bin` convention. The headless-shell variant ships in a
# sibling pkg `chromium-headless-shell-bin` so consumers (and download
# size) only pay for the variant they need. Building chromium from
# source needs depot_tools, a hermetic clang toolchain, a ~30 GB git
# checkout, and 4-8 hours of build time — none of which is packaged.
# CLAUDE.md's "build from source" rule has an explicit carve-out for
# this case. The bare `chromium` name is intentionally left available
# for a future source-built pkg.
#
# Source mix — both legs are true open-source Chromium (BSD-3-Clause),
# deliberately NOT Chrome for Testing: CfT is a *branded Google Chrome*
# build governed by the Chrome ToS, which does not permit redistribution
# — and our binary cache redistributes (gominimal/inbox#284). Playwright
# itself stopped publishing its own linux-x64 Chromium (its registry now
# fetches CfT directly for x64), so:
#   amd64 → Chromium's official snapshot bucket
#     (chromium-browser-snapshots), pinned to `snapshot_position` — the
#     main-branch position Chrome `browser_version` branched from
#     (chromiumdash fetch_version), i.e. the same code the arm64 build
#     was cut from, minus branch cherry-picks.
#   arm64 → Playwright's own arm64 Chromium build on cdn.playwright.dev
#     (Google publishes no linux-arm64; Playwright still builds arm64).
#
# `revision` is the Playwright browser-revision number from
# packages/playwright-core/browsers.json. Revision 1234 ↔ Chrome 151.0.7922.34
# ↔ playwright-core ^1.59. `snapshot_position` must be re-derived whenever
# `browser_version` bumps. Keep all three in lockstep with
# chromium-headless-shell-bin.
#
# Consumer note (Playwright): files are laid out under
# /usr/share/playwright-browsers/chromium-<rev>/ in Playwright's
# registry layout, so installing both this pkg and
# chromium-headless-shell-bin and setting
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` lets
# @playwright/test discover both binaries with zero further config —
# provided the installed playwright-core revision matches `revision`.
# If it doesn't, pass `executablePath: '/bin/chromium'` (or
# '/bin/chromium-headless-shell' from the headless-shell pkg) to
# bypass the registry lookup. See packages/chromium-bin/README.md.
let revision = "1234" in
let browser_version = "151.0.7922.34" in
let snapshot_position = "1654408" in
{
  name = "chromium-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/%{snapshot_position}/chrome-linux.zip",
          sha256 = "c094b77ad8d462bacd54769c5aa1fcd2e9d61f9b146796bbcded9276cdc40a5e",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-linux-arm64.zip",
          sha256 = "b5ad7d8fe70f230b34198ddb5626d717c016db2f627cb44b922babbcaf3479b9",
        } | Source,
    } target,
    base,
    unzip,
  ],
  runtime_deps = [
    bash,
    glibc,
    gcc,
    alsa-lib,
    cairo,
    cups,
    dbus,
    expat,
    fontconfig,
    freetype,
    fribidi,
    glib,
    harfbuzz,
    libdrm,
    libx11,
    libxcb,
    libxcomposite,
    libxdamage,
    libxext,
    libxfixes,
    libxkbcommon,
    libxrandr,
    libxrender,
    libxshmfence,
    libxtst,
    mesa,
    nss,
    nspr,
    pango,
    atk,
    at-spi2-core,
    eudev,
    liberation-fonts,
  ],

  cmd = "./build.sh",
  build_args = {
    include revision,
    include browser_version,
  },

  outputs = {
    bin = { glob = "usr/bin/chromium" } | OutputBin,
    data = { glob = "usr/share/playwright-browsers/chromium-*/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = browser_version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "microsoft",
        repo = "playwright",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/%{snapshot_position}/chrome-linux.zip",
          { arch = 'Arm64, .. } => "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-linux-arm64.zip",
        } target,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/chromium --version",
    launch_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/chromium --headless --no-sandbox --disable-gpu --disable-dev-shm-usage --dump-dom 'data:text/html,<title>chromium-launch-ok</title>' | grep -q chromium-launch-ok"],
        ],
      } | Test,
  },
} | BuildSpec
