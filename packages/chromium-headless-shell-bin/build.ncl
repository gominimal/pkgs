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
# ⚠ CHANNEL: this package tracks Chrome for Testing **Stable**, so unlike
# chromium-bin it is NOT pre-stable. The pkgmgr-rs#646 caveat ("ahead of
# the published feed", NOT "audited clean") applied while we tracked
# Playwright's pinned pre-stable Chromium; on Stable a CVE match is an
# ordinary version-tracking question again. Do NOT retarget this at Beta:
# Beta matches ~0 CVEs today and a few hundred the day that major goes
# stable. The security win is the CHANNEL, not the hostname.
#
# SOURCE: both legs are Chrome for Testing `chrome-headless-shell`, one
# zip per arch, no grafting. This deliberately diverges from chromium-bin,
# which stays on true open-source Chromium:
#
#   The inbox#284 decision (CfT is branded Google Chrome, whose ToS does
#   not permit redistribution, and our cache redistributes) is about the
#   **`chrome` bundle**. It does not hold for `chrome-headless-shell`.
#   Verified 2026-09-18 against both CfT zips at 153.0.8010.52:
#     * ZERO `WidevineCdm/**` entries on either arch (the full `chrome`
#       bundle ships libwidevinecdm.so under a "not open source ...
#       separate license agreement with Google" grant; this ships none)
#     * each carries `LICENSE.headless_shell` (2,352,658 B) opening with
#       the Chromium Project BSD-3-Clause grant, with zero occurrences of
#       that proprietary language
#   So headless-shell stays BSD-3-Clause and stays cache-served. It does
#   NOT need the `redistributable = false` posture gominimal/pkgs#684
#   assumed every CfT-sourced leg would need.
#
# WHY WE MOVED: Playwright stopped building linux-arm64 Chromium. r1243
# was the last one; re-verified 2026-09-18 following redirects, r1243 ->
# HTTP 200 and r1245/1250/1260/1270 -> HTTP 400. There is no newer
# revision to walk to, so the old arm64 leg was a dead end, not a pin.
#
# WHAT THIS DELETED: the amd64 snapshot bucket ships headless-shell.zip
# with only the binary + .paks, so build.sh used to graft icudtl.dat, the
# v8 snapshot and the GL/SwiftShader libs out of chrome-linux.zip, and
# borrow `headless_command_resources.pak` from the arm64 Playwright zip
# because no snapshot artifact ships it. CfT carries all of it inline
# (287 entries per arch; the pak present at an identical 3,109 B on both,
# confirming it is arch-independent grit data). Hence one Source per arch
# instead of three, and `snapshot_position` is gone — which also retires
# the re-derivation trap of pkgmgr-rs#540.
#
# SIDE EFFECT — the updater is unstuck. `pkg_action_state` read
# `state=failed` for this package from 2026-07-15 with "multi-arch
# build.ncl has 4 sha256 literals but the updater can map only 3". Those
# 4 literals were only 3 distinct artifacts (the arm64 zip appeared
# twice). Two literals now, one per arch.
#
# `revision` is retained ONLY as the Playwright registry directory key
# (`chromium_headless_shell-<revision>` under
# /usr/share/playwright-browsers), so `PLAYWRIGHT_BROWSERS_PATH` consumers
# pinned to playwright-core ^1.59 still resolve. It no longer names a
# Playwright build. `browser_version` is the CfT Stable version and is the
# only pin to bump.
let revision = "1243" in
let browser_version = "153.0.8010.52" in
{
  name = "chromium-headless-shell-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    # One complete CfT bundle per arch. Both extract to a single
    # top-level dir matching Playwright's registry layout
    # (chrome-headless-shell-linux64 / -linux-arm64, binary
    # `chrome-headless-shell`), so build.sh needs no renames.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-headless-shell-linux64.zip",
          sha256 = "944dc1eae654637fed4d57650198774f9c43b45f34e48febb84f43c541b5de76",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chrome-headless-shell-linux-arm64.zip",
          sha256 = "d8e97f3bf2537280a60f4b9bae8e9f463d112c9cdce349f89c2c7611150282d7",
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
          { arch = 'Amd64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-headless-shell-linux64.zip",
          { arch = 'Arm64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chrome-headless-shell-linux-arm64.zip",
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
