let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
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
let mesa = import "../mesa/build.ncl" in
let nss = import "../nss/build.ncl" in
let nspr = import "../nspr/build.ncl" in
let pango = import "../pango/build.ncl" in
let atk = import "../atk/build.ncl" in
let at-spi2-core = import "../at-spi2-core/build.ncl" in
let eudev = import "../eudev/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in

# Prebuilt Chromium headless-shell — the stripped headless build that
# Playwright's `chromium.launch()` and Puppeteer drive in default
# headless mode. Sibling to `chromium-bin` (the full headed browser);
# they share a revision and a layout under
# /usr/share/playwright-browsers/. Consumers that only need headless
# rendering (mermaid-cli, e.g.) depend on this pkg alone to avoid
# pulling the full browser.
#
# Source mix mirrors chromium-bin: amd64 from Google's Chrome for
# Testing bucket, arm64 from Playwright's own arm64 build via
# cdn.playwright.dev. The same Playwright revision identifies both
# arches.
#
# `revision` is the Playwright browser-revision number from
# packages/playwright-core/browsers.json. Revision 1217 ↔ Chrome 147.0.7727.15
# ↔ playwright-core ^1.58.0. Keep in lockstep with chromium-bin.
let revision = "1217" in
let browser_version = "147.0.7727.15" in
{
  name = "chromium-headless-shell-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-headless-shell-linux64.zip",
          sha256 = "cf779cd5486f3fc5a18bea4ac606026a1667ae16efaee15af51bd3ad3ae01092",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux-arm64.zip",
          sha256 = "6db7041d8a273093b8f2c7a7338766c6d12abb06cd0253fc91feebb71ecd4635",
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
    bin = { glob = "usr/bin/chromium-headless-shell" } | OutputBin,
    data = { glob = "usr/share/playwright-browsers/chromium_headless_shell-*/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = browser_version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "microsoft",
        repo = "playwright",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-headless-shell-linux64.zip",
          { arch = 'Arm64, .. } => "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux-arm64.zip",
        } target,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/chromium-headless-shell --version",
  },
} | BuildSpec
