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

# Prebuilt Chromium headless-shell — the stripped headless build that
# Playwright's `chromium.launch()` and Puppeteer drive in default
# headless mode. Sibling to `chromium-bin` (the full headed browser);
# they share a revision and a layout under
# /usr/share/playwright-browsers/. Consumers that only need headless
# rendering (mermaid-cli, e.g.) depend on this pkg alone to avoid
# pulling the full browser.
#
# Source mix mirrors chromium-bin (see its header for the full
# rationale): both legs are true open-source Chromium, deliberately NOT
# Chrome for Testing (a branded Google Chrome build whose ToS does not
# permit redistribution — our cache redistributes, gominimal/inbox#284).
# amd64 comes from Chromium's official snapshot bucket at
# `snapshot_position` (the main-branch position `browser_version`
# branched from); arm64 from Playwright's own arm64 build.
#
# `revision` is the Playwright browser-revision number from
# packages/playwright-core/browsers.json. Revision 1234 ↔ Chrome 151.0.7922.34
# ↔ playwright-core ^1.59. `snapshot_position` must be re-derived whenever
# `browser_version` bumps. Keep all three in lockstep with chromium-bin.
let revision = "1234" in
let browser_version = "151.0.7922.34" in
let snapshot_position = "1654408" in
{
  name = "chromium-headless-shell-bin",
  build_deps =
    [
      { file = "build.sh" } | Local,
      match {
        { arch = 'Amd64, .. } =>
          {
            url = "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/%{snapshot_position}/headless-shell.zip",
            sha256 = "4cd2324a9343cf01fa192902c203250f73a14b6e60f4a775f84a2b26314c5cfa",
          } | Source,
        { arch = 'Arm64, .. } =>
          {
            url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux-arm64.zip",
            sha256 = "b03443e1e1a60d06e07b6cdfe650b8c2bfcbb3db497d2b652f73dc6912f4ae15",
          } | Source,
      } target,
      base,
      unzip,
    ]
    @ (
      match {
        # The snapshot bucket's headless-shell.zip ships only the binary + its
        # .paks — no icudtl.dat / v8 snapshot / GL fallback libs (the CfT and
        # Playwright bundles carry them inline). Graft them from the full-browser
        # zip at the SAME snapshot position; build.sh copies just those members.
        { arch = 'Amd64, .. } =>
          [
            {
              url = "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/%{snapshot_position}/chrome-linux.zip",
              sha256 = "c094b77ad8d462bacd54769c5aa1fcd2e9d61f9b146796bbcded9276cdc40a5e",
            } | Source,
            # headless_command_resources.pak (the pak implementing --dump-dom &
            # friends in standalone headless) ships in NO snapshot artifact —
            # the full build rolls it into chrome's resources.pak. It's tiny
            # (~3 KB), arch-independent grit data, so borrow it from the
            # same-branch Playwright arm64 bundle (the arm64 leg's exact
            # artifact, same pin).
            {
              url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux-arm64.zip",
              sha256 = "b03443e1e1a60d06e07b6cdfe650b8c2bfcbb3db497d2b652f73dc6912f4ae15",
            } | Source,
          ],
        # Playwright's arm64 bundle is already complete.
        { arch = 'Arm64, .. } => [],
      } target
    ),
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
    bin = { glob = "usr/bin/chromium-headless-shell" } | OutputBin,
    data = { glob = "usr/share/playwright-browsers/chromium_headless_shell-*/**", allow_executable = true } | OutputData,
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
          { arch = 'Amd64, .. } => "https://commondatastorage.googleapis.com/chromium-browser-snapshots/Linux_x64/%{snapshot_position}/headless-shell.zip",
          { arch = 'Arm64, .. } => "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux-arm64.zip",
        } target,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/chromium-headless-shell --version",
    launch_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/chromium-headless-shell --no-sandbox --disable-gpu --disable-dev-shm-usage --dump-dom 'data:text/html,<title>shell-launch-ok</title>' | grep -q shell-launch-ok"],
        ],
      } | Test,
  },
} | BuildSpec
