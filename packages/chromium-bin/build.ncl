let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
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

# Prebuilt full Chrome browser (headed mode), named with the
# Gentoo/AUR `-bin` convention. The headless-shell variant ships in a
# sibling pkg `chromium-headless-shell-bin` so consumers (and download
# size) only pay for the variant they need. Building chromium from
# source needs depot_tools, a hermetic clang toolchain, a ~30 GB git
# checkout, and 4-8 hours of build time — none of which is packaged.
# CLAUDE.md's "build from source" rule has an explicit carve-out for
# this case. The bare `chromium` name is intentionally left available
# for a future source-built pkg.
#
# ⚠ CHANNEL: Chrome for Testing **Stable**, the same channel and version
# as chromium-headless-shell-bin. This retires the "pre-stable BY DESIGN"
# posture of pkgmgr-rs#646: that existed only because we tracked
# Playwright's pinned Chromium, which rode ahead of Stable. On Stable a
# CVE match is an ordinary version-tracking question. Do NOT retarget
# this at Beta — Beta matches ~0 CVEs today and a few hundred the day
# its major goes stable. The security win is the channel.
#
# SOURCE: Chrome for Testing `chrome`, one zip per arch, no grafting.
# WHY WE MOVED: Playwright stopped building linux-arm64 Chromium. r1243
# was the last one (r1245/1250/1260/1270 -> HTTP 400, re-verified
# 2026-09-18; r1249 -> 400 on 2026-10-18), so the old arm64 leg was a
# dead end and pkgmgr refused every newer target. CfT now publishes the
# full `chrome` bundle for linux-arm64 as well as linux64 (supported
# since 153.0.8001.0), so both legs come from one source at one version
# and `snapshot_position` is gone (also retiring the pkgmgr-rs#540
# re-derivation trap).
#
# ⚠ LICENSING — this is NOT the headless-shell situation. Verified
# 2026-10-18 against both CfT `chrome` zips at 155.0.8059.84:
#   * each ships WidevineCdm/_platform_specific/linux_<arch>/libwidevinecdm.so
#     under WidevineCdm/LICENSE: "You may not use, modify, sell, or
#     otherwise distribute the Software without a separate license
#     agreement with Google. The Software is not open source software."
#     build.sh DELETES WidevineCdm/ and fails the build if any Widevine
#     file survives. Chrome runs fine without it (no EME/DRM playback,
#     which nothing headless needs).
#   * unlike chrome-headless-shell (LICENSE.headless_shell, the Chromium
#     BSD-3-Clause grant) and chromedriver (LICENSE.chromedriver), the
#     `chrome` bundle carries NO license file. Its ABOUT reads "Google
#     Chrome / Copyright 2026 Google LLC. All rights reserved. ... See
#     the Terms of Service at chrome://terms", the binary brands itself
#     "Google Chrome for Testing", and its strings point at the "Chrome
#     and ChromeOS Additional Terms of Service". That is the branded-Chrome
#     ToS posture gominimal/inbox#284 ruled non-redistributable.
#   So `license_spdx` names the Google terms rather than claiming
#   BSD-3-Clause, and this package must stay OUT of the public binary
#   cache (consumers fetch the zip from Google and unpack it locally).
#   The exclusion is build-infra policy: the build-servers
#   NON_REDISTRIBUTABLE_NAMES denylist (the `redistributable = false`
#   attr was withdrawn in pkgs#536), which must list `chromium-bin`
#   BEFORE this recipe reaches main.
#
# `revision` is retained ONLY as the Playwright registry directory key
# (`chromium-<revision>` under /usr/share/playwright-browsers), kept in
# lockstep with chromium-headless-shell-bin. It no longer names a
# Playwright build. `browser_version` is the CfT Stable version and is
# the only pin to bump (pkgmgr's chromium resolver does so, together
# with both sha256s).
#
# Consumer note (Playwright): CfT's zip layout (chrome-linux64/chrome,
# chrome-linux-arm64/chrome) is exactly what playwright-core >= 1.63
# expects on both arches, so installing this pkg and setting
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` lets a
# playwright-core 1.63.x (revision 1243) consumer discover it with no
# further config. Any other playwright-core version: pass
# `executablePath: '/bin/chromium'`. See packages/chromium-bin/README.md.
let revision = "1243" in
let browser_version = "155.0.8059.84" in
{
  name = "chromium-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    # One complete CfT bundle per arch. Both extract to a single
    # top-level dir matching Playwright's registry layout
    # (chrome-linux64 / chrome-linux-arm64, binary `chrome`), so build.sh
    # needs no renames. CfT publishes no checksum file; the sha256s were
    # computed from the downloads.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-linux64.zip",
          sha256 = "cf0f049892dea22e6a6db26d47ed0d7776b7158edcbec4634086633df8bafcbc",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chrome-linux-arm64.zip",
          sha256 = "1692a407908867de88eb1f1b2a93ca47c348d8fb2e3c04752d966e0f2e0344b4",
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
      # Google's terms, not BSD-3-Clause: see LICENSING above. The
      # Chromium sources are BSD-3-Clause, but these are Google's
      # branded binaries and ship without that grant.
      license_spdx = "LicenseRef-Google-Chrome-for-Testing-ToS",
      source_provenance = {
        category = 'GithubRepo,
        owner = "microsoft",
        repo = "playwright",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chrome-linux64.zip",
          { arch = 'Arm64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chrome-linux-arm64.zip",
        } target,
    } | Attrs,

  tests = {
    # The exact pinned version, not just "it runs": CfT prints
    # "Google Chrome for Testing <version>".
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/chromium --version | grep -qF ' %{browser_version}'"],
        ],
      } | Test,
    launch_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/chromium --headless=new --no-sandbox --disable-gpu --disable-dev-shm-usage --dump-dom 'data:text/html,<title>chromium-launch-ok</title>' | grep -q chromium-launch-ok"],
        ],
      } | Test,
    # Playwright registry layout (PLAYWRIGHT_BROWSERS_PATH discovery) is
    # in place, and the proprietary Widevine CDM is NOT shipped.
    layout_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "d=/usr/share/playwright-browsers/chromium-%{revision}; case \"$(uname -m)\" in x86_64) i=chrome-linux64 ;; *) i=chrome-linux-arm64 ;; esac; test -x \"$d/$i/chrome\" && test -e \"$d/INSTALLATION_COMPLETE\" && test ! -e \"$d/$i/WidevineCdm\""],
        ],
      } | Test,
  },
} | BuildSpec
