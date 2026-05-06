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

# Prebuilt: same Chromium-from-source caveat as chrome-for-testing.
# Playwright redirects x86_64 download requests to Google's Chrome for Testing
# bucket (so the amd64 binary is the same artifact as CfT linux64), but for
# linux-arm64 — which Google does not publish under CfT — Playwright builds
# its own from chromium source and hosts on Microsoft's CDN. We pin both.
#
# Playwright treats `chromium` (full browser, used in headed mode) and
# `chromium-headless-shell` (stripped headless build, used by chromium.launch()
# in default headless mode) as TWO separate browser installs — see
# packages/playwright-core/browsers.json upstream — so we ship both. Without
# the headless-shell binary, `chromium.launch()` fails with "Executable
# doesn't exist at .../chromium_headless_shell-<rev>/...".
#
# The four zips use different top-level directory names per (arch × variant):
#   chromium      amd64 → chrome-linux64/                   (CfT-style)
#   chromium      arm64 → chrome-linux/                     (Playwright's own)
#   shell         amd64 → chrome-headless-shell-linux64/    (CfT-style)
#   shell         arm64 → chrome-linux/                     (Playwright's own)
# which is why build.sh extracts each zip into a separate scratch dir before
# installing — Playwright's `@playwright/test` registry expects exactly those
# directory names under chromium-<rev>/ and chromium_headless_shell-<rev>/.
#
# `revision` is the Playwright browser-revision number from
# packages/playwright-core/browsers.json. Revision 1200 ↔ Chrome 143.0.7499.4
# ↔ playwright-core ^1.57.0. `browser_version` is recorded for humans only.
let revision = "1200" in
let browser_version = "143.0.7499.4" in
{
  name = "playwright-chromium",
  build_deps = [
    { file = "build.sh" } | Local,
    # Full chromium browser (used in headed mode)
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-linux.zip",
          sha256 = "ab56b2a7955c2961f74348e2349f1e907489283da23dba37c730b624e4d670bb",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-linux-arm64.zip",
          sha256 = "e73eeb680312e96d4f8fbca589ad42e3fb719178b4bdd8707f9fe796123bf48b",
        } | Source,
    } target,
    # Chromium headless-shell (used by chromium.launch() default-headless mode)
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux.zip",
          sha256 = "a9a525cb3832d59a810f78f8ba6c5ed3592a6a488984627f5d827c2a365c8a5a",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-headless-shell-linux-arm64.zip",
          sha256 = "2321e3d1d497b21b79aa822d6c9e13c5b155249a9df7cf028f009f1159907c75",
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
    bin = { glob = "usr/bin/playwright-chromium" } | OutputBin,
    data = { glob = "usr/share/playwright-chromium/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = browser_version,
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/playwright-chromium --version",
  },
} | BuildSpec
