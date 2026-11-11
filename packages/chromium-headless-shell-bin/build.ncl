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
# headless mode, laid out under /usr/share/playwright-browsers/ in
# Playwright's registry format. It is the tree's only Chromium today:
# agent-browser and mermaid-cli drive it. The full-browser sibling,
# chromium-bin, was pulled (stuck at 156, no ungoogled-chromium-portablelinux
# 157 release); it can come back when a good full-browser source exists.
#
# ⚠ CHANNEL: this package tracks Chrome for Testing **Stable**, so it is NOT
# pre-stable. The pkgmgr-rs#646 caveat ("ahead of
# the published feed", NOT "audited clean") applied while we tracked
# Playwright's pinned pre-stable Chromium; on Stable a CVE match is an
# ordinary version-tracking question again. Do NOT retarget this at Beta:
# Beta matches ~0 CVEs today and a few hundred the day that major goes
# stable. The security win is the CHANNEL, not the hostname.
#
# SOURCE: both legs are Chrome for Testing `chrome-headless-shell`, one
# zip per arch, no grafting. This deliberately diverges from the old
# chromium-bin, which stayed on true open-source Chromium:
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
#
# ⚠ CVE-2026-111943 (eMudhra intermediate key compromise): PARTLY
# MITIGATED at 157.0.8103.38, and nothing package-side can close the rest.
# Checked against the Chromium 157.0.8103.38 sources:
#   * The 8 compromised intermediate keys ARE blocked. `kSPKIBlockList`
#     (net/cert/cert_verify_proc_blocklist.inc) carries all 8 SPKI hashes
#     (upstream chromium/src da63b94c, main@{#1723080}), so any chain through
#     one of them is refused. The `emudhra_spki_blocklist` test below checks
#     the shipped binary for them.
#   * emSign ECC Root CA - G3 is STILL TRUSTED. The compiled-in
#     root_store.textproto is version_major 42 and still lists it
#     (sha256 86a1ecba...). Chrome Root Store v43 (chromium/src 8793082f,
#     main@{#1723181}) removes it; 158.0.8127.18 carries v43, 157 does not.
#     A certificate under that root that avoids the 8 keys validates until
#     this package reaches 158.
#   * On Linux the verifier uses only the Chrome Root Store
#     (`chrome_root_store_only`, net/features.gni), so /etc/ssl/certs and
#     packages/ca-certificates/distrust.txt do not reach it, and it gets no
#     CRLSet or root-store component updates.
#   * chrome-headless-shell has no platform policy loader (Chromium deleted
#     headless/lib/browser/policy/ between 145 and 150; the 155.0.8059.84
#     binary contains no /etc/.../policies path and no
#     "CADistrustedCertificates" string), so the chromium-policies
#     distrust policy cannot close the root gap. Adding the chromium-policies
#     dep here would only look like a fix.
# Bump to 158 (the first CfT Stable with root store v43) to remove the root.
# Tracked in gominimal/pkgmgr-rs#1028.
let revision = "1243" in
let browser_version = "157.0.8103.50" in
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
          sha256 = "7bf0d41e424efd1d6281c4162993ab9dc5de92fac213c211614905a71c057d0f",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chrome-headless-shell-linux-arm64.zip",
          sha256 = "55add1fa634756811fd644094ec226fc7e405be698fb07dbf0634bca689e293a",
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
      # Chrome for Testing, the same home chromedriver-bin names. Chrome's
      # CVEs do NOT come through this repo: supply-chain's
      # package_cpe_identity.toml maps the package NAME
      # `chromium-headless-shell-bin` to google:chrome (pkgmgr-rs#1029), and
      # that identity takes precedence over this provenance. It is keyed by
      # name because chromedriver-bin shares this repo and is not the
      # browser. Renaming the package without moving that entry makes it scan
      # 0/0/0. pkgmgr's chromium resolver checks and updates it by name.
      source_provenance = {
        category = 'GithubRepo,
        owner = "GoogleChromeLabs",
        repo = "chrome-for-testing",
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
    # CVE-2026-111943: the shipped binary carries the 8 compromised eMudhra
    # intermediate keys of Chromium's `kSPKIBlockList` (each a raw 32-byte
    # SHA-256 of the SPKI, the same 8 keys chromium-policies' policy lists).
    # A build without the upstream blocklist change fails here. Checked on the
    # CfT linux64 zips: 157.0.8103.38 and 156.0.8078.79 pass (the change was
    # merged back to 156), 156.0.8078.47 and 155.0.8059.84 fail. It says
    # nothing about the emSign ECC G3 root, which this build still trusts
    # (see the comment above `revision`). The last command is the negative
    # control: the first key's bytes reversed must NOT be found, so the
    # search cannot pass vacuously. None of the hashes holds a 0x00 or 0x0a
    # byte, so each is a single fixed-string line for grep.
    emudhra_spki_blocklist =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              shopt -s nullglob
              bins=(/usr/share/playwright-browsers/chromium_headless_shell-*/chrome-headless-shell-linux*/chrome-headless-shell)
              test "${#bins[@]}" -eq 1
              bin=${bins[0]}
              has() {
                local pat
                pat=$(printf "$(printf '%s' "$1" | sed 's/../\\x&/g')")
                LC_ALL=C grep -qaF -- "$pat" "$bin"
              }
              keys=(
                49dd353dc2b919a3770645117d0e60c16115e7d1bc259eefe734b00ea434fe5f
                ebed6475c2c2d80fcb199f3fe8dd6e6b3ce60b77eb15d4e42c3dec0c6f5b5105
                5c0660a2b164910d8ff589c18e14552e9e0ec237dcefe2cb736d41a4811f81a0
                43bffa19d6ef651451f6841e019931e96f6f2eaeff28ab4b6f1ce4576de2717b
                63ecefee431d49523bc1136c4e72d0206a477086caf606cd5cf025686c109cf8
                e0254c7fcdc265e2f0f8a428dabb75ab4ae039b4872d62f5ee57f0877d5a8a41
                92c063d67e8f14db71d288e11266ffdaf69cbf115f7bab14f3bc2f68d25e0e30
                ec4ffa1ad0ac88081314b7aaffef6a91f97cd57291bb5ba686c5415f5eb4f6b6
              )
              for h in "${keys[@]}"; do
                has "$h" || { echo "blocklist key $h not in $bin" >&2; exit 1; }
              done
              ! has 5ffe34a40eb034e7ef9e25bcd1e71561c1600e7d11450677a319b9c23d35dd49
            "%,
          ],
        ],
      } | Test,
  },
} | BuildSpec
