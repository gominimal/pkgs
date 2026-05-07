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

# Prebuilt blob, named with the Gentoo/AUR `-bin` convention. Building
# chromium from source needs depot_tools, a hermetic clang toolchain, a
# ~30 GB git checkout, and 4-8 hours of build time — none of which is
# packaged. CLAUDE.md's "build from source" rule has an explicit carve-out
# for this case. The bare `chromium` name is intentionally left available
# for a future source-built pkg.
#
# Source mix: amd64 comes straight from Google's Chrome for Testing
# bucket (Playwright's own cdn.playwright.dev URL just redirects there for
# amd64, and that redirect is unreliable on newer revisions — MS's CDN
# doesn't host amd64 zips). For linux-arm64 — which Google does not
# publish under CfT — we use Playwright's own arm64 build hosted on
# Microsoft's CDN via cdn.playwright.dev. The same Playwright revision
# identifies matching builds across both arches; the corresponding Chrome
# version (used to address the CfT bucket) lives in `browser_version`.
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
# packages/playwright-core/browsers.json. Revision 1217 ↔ Chrome 147.0.7727.15
# ↔ playwright-core ^1.58.0. `browser_version` is recorded for humans only and
# is also used to address the Chrome-for-Testing bucket on amd64.
#
# Consumer note (Playwright): files are laid out under /usr/share/chromium-bin
# in Playwright's registry layout (chromium-<rev>/, chromium_headless_shell-<rev>/),
# so setting `PLAYWRIGHT_BROWSERS_PATH=/usr/share/chromium-bin` lets
# @playwright/test discover both binaries with zero further config — provided
# the installed playwright-core revision matches `revision` above. If it
# doesn't, pass `executablePath: '/bin/chromium-headless-shell'` (or
# '/bin/chromium' for headed) to bypass the registry lookup. See
# packages/chromium-bin/README.md.
let revision = "1217" in
let browser_version = "147.0.7727.15" in
{
  name = "chromium-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    # Full chromium browser (used in headed mode)
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-linux64.zip",
          sha256 = "04883e331b31448d6255fa058f0e1c7e8657c004da1f8a1c04eb28855a37ec6c",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://cdn.playwright.dev/dbazure/download/playwright/builds/chromium/%{revision}/chromium-linux-arm64.zip",
          sha256 = "563d09cb67274c26eeba36c67032cbc22dc44534259c15ea469dd818725b1139",
        } | Source,
    } target,
    # Chromium headless-shell (used by chromium.launch() default-headless mode)
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
    # /usr/bin/chromium               → full chromium browser (headed)
    # /usr/bin/chromium-headless-shell → headless-shell variant (used by
    #                                    Puppeteer/@playwright/test default headless)
    bins = { glob = "usr/bin/chromium*" } | OutputBin,
    data = { glob = "usr/share/chromium-bin/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = browser_version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "microsoft",
        repo = "playwright",
      },
      build_cost_multiple = 3,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/chromium --version",
    headless_shell_smoketest = standaloneTest "/bin/chromium-headless-shell --version",
  },
} | BuildSpec
