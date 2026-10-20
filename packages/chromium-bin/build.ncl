let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in

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

# Prebuilt full Chromium browser (headed mode), named with the
# Gentoo/AUR `-bin` convention. The headless-shell variant ships in a
# sibling pkg `chromium-headless-shell-bin` so consumers (and download
# size) only pay for the variant they need. Building chromium from
# source needs depot_tools, a hermetic clang toolchain, a ~30 GB git
# checkout, and 4-8 hours of build time — none of which is packaged.
# CLAUDE.md's "build from source" rule has an explicit carve-out for
# this case. The bare `chromium` name is intentionally left available
# for a future source-built pkg (pkgmgr-rs#681).
#
# SOURCE (INTERIM, decided 2026-10-20): ungoogled-chromium-portablelinux
# (github.com/ungoogled-software/ungoogled-chromium-portablelinux), one
# `*_linux.tar.xz` per arch from the GitHub release tagged
# `<chromium version>-<ungoogled_revision>`. It is a Stable-branch
# Chromium build (is_official_build, use_sysroot) with ungoogled's patch
# set on top, published for x86_64 AND arm64 for every Stable point
# release, ~2 days after Google. It is the stop-gap, not the end state:
# it is what lets the package track Stable on both arches again while the
# source build (#681) or another source is worked out.
#
# WHY WE MOVED: the old legs were both dead ends. arm64 came from
# Playwright's CDN, and Playwright stopped building linux-arm64 Chromium
# after r1243 (153.0.8010.12). amd64 came from chromium-browser-snapshots,
# which builds only main-branch positions — never a Stable-branch
# cherry-pick — so its binary was older code than the `browser_version`
# it was labelled with. Chrome for Testing (pkgs#928) ships both arches
# but is Google-branded under the Chrome ToS with a proprietary Widevine
# CDM, which our public binary cache cannot redistribute.
#
# LICENSING: BSD-3-Clause (ungoogled-chromium's own LICENSE) over
# Chromium's BSD-3-Clause and bundled third-party licenses (listed at
# chrome://credits). Redistributable. No Widevine CDM in the tarball
# (build.sh fails if one ever appears). PATENT NOTE: built with
# `proprietary_codecs=true ffmpeg_branding="Chrome"` (H.264/AAC decoders
# in the bundled ffmpeg), as every redistributed Chromium binary we
# evaluated is — copyright permits redistribution; patent licensing is a
# separate question.
#
# BEHAVIOUR vs vanilla Chromium (ungoogled's patch set): no Safe Browsing,
# no Google sign-in / sync, no Google API keys; installing from the Chrome
# Web Store does not work (domain substitution breaks the CRX install
# flow). Unpacked extensions via `--load-extension` work. No Widevine,
# so no DRM (EME) playback.
#
# PINS: `browser_version` is the Chromium version (also `upstream_version`,
# so scanning compares the real Stable version). `ungoogled_revision` is
# ungoogled's packaging revision — the `-N` in the release tag; a `-2` of
# the same Chromium version is an update. pkgmgr's chromium resolver bumps
# both and both sha256s, and proposes a release only when BOTH arch
# tarballs are attached. `revision` is ONLY the Playwright registry
# directory key (`chromium-<revision>` under /usr/share/playwright-browsers),
# kept in lockstep with chromium-headless-shell-bin; it names no build.
#
# Consumer note (Playwright): the browser is laid out as
# /usr/share/playwright-browsers/chromium-<revision>/chrome-linux64/chrome
# (amd64) or .../chrome-linux-arm64/chrome (arm64, plus a `chrome-linux`
# compat symlink to the pre-2026-10 arm64 path), so
# `PLAYWRIGHT_BROWSERS_PATH=/usr/share/playwright-browsers` lets a
# playwright-core 1.63.x (revision 1243) consumer discover it with no
# further config. Any other playwright-core version: pass
# `executablePath: '/bin/chromium'`. See packages/chromium-bin/README.md.
let revision = "1243" in
let browser_version = "155.0.8059.84" in
let ungoogled_revision = "1" in
{
  name = "chromium-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    # One tarball per arch, straight from the GitHub release. Upstream
    # publishes no checksum file or signature; each sha256 was computed
    # from the download and matches the asset digest GitHub reports.
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/download/%{browser_version}-%{ungoogled_revision}/ungoogled-chromium-%{browser_version}-%{ungoogled_revision}-x86_64_linux.tar.xz",
          sha256 = "7e376c47b2650f846984f32e4962b33703e5abe09681009cf4f3f336e1125f13",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/download/%{browser_version}-%{ungoogled_revision}/ungoogled-chromium-%{browser_version}-%{ungoogled_revision}-arm64_linux.tar.xz",
          sha256 = "5b4de24d19d7a5e5240233a4efd2f1f62be50f82793ee1b90673479148474ade",
        } | Source,
    } target,
    base,
  ],
  # Covers every DT_NEEDED of `chrome` and `chromedriver` on both arches
  # (sysroot build: max GLIBC_2.25 / GCC_4.5.0). The rest are dlopen'd or
  # reached through those (fontconfig/freetype/harfbuzz/fribidi via pango,
  # libdrm/libxshmfence via mesa's gbm, libxtst/libxrender, fonts).
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
    include ungoogled_revision,
  },

  outputs = {
    bin = { glob = "usr/bin/chromium" } | OutputBin,
    data = { glob = "usr/share/playwright-browsers/chromium-*/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = browser_version,
      license_spdx = "BSD-3-Clause",
      # NOT the origin of these bytes (`binary_from` says where they come
      # from), but LOAD-BEARING for vulnerability scanning: supply-chain's
      # cpe_remap maps pkg:github/microsoft/playwright -> google:chrome,
      # which is how BOTH chromium packages see Chrome's CVEs at all.
      # ungoogled-chromium <v>-N is Chromium <v> plus patches, so Chrome's
      # CVE ranges apply to `upstream_version` as-is. Removing or changing
      # this without a matching cpe_remap/cpe_identity entry makes the
      # package scan 0/0/0 — a silent false negative. Re-identifying the
      # pair is a separate, coordinated change (pkgmgr-rs#825).
      source_provenance = {
        category = 'GithubRepo,
        owner = "microsoft",
        repo = "playwright",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/download/%{browser_version}-%{ungoogled_revision}/ungoogled-chromium-%{browser_version}-%{ungoogled_revision}-x86_64_linux.tar.xz",
          { arch = 'Arm64, .. } => "https://github.com/ungoogled-software/ungoogled-chromium-portablelinux/releases/download/%{browser_version}-%{ungoogled_revision}/ungoogled-chromium-%{browser_version}-%{ungoogled_revision}-arm64_linux.tar.xz",
        } target,
    } | Attrs,

  tests = {
    # The exact pinned version as a whole token, not just "it runs".
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "v=$(/bin/chromium --version); echo \"$v\"; case \" $v \" in *\" %{browser_version} \"*) ;; *) echo \"expected %{browser_version}\" >&2; exit 1 ;; esac"],
        ],
      } | Test,
    # Offline: render a data: URL headlessly and read the DOM back.
    launch_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/chromium --headless --no-sandbox --disable-gpu --disable-dev-shm-usage --dump-dom 'data:text/html,<title>chromium-launch-ok</title>' | grep -q chromium-launch-ok"],
        ],
      } | Test,
    # The bundled chromedriver matches the browser exactly.
    chromedriver_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "d=/usr/share/playwright-browsers/chromium-%{revision}; case \"$(uname -m)\" in x86_64) i=chrome-linux64 ;; *) i=chrome-linux-arm64 ;; esac; v=$(\"$d/$i/chromedriver\" --version); echo \"$v\"; case \" $v \" in *\" %{browser_version} \"*) ;; *) echo \"expected %{browser_version}\" >&2; exit 1 ;; esac"],
        ],
      } | Test,
    # Playwright registry layout in place; Qt shims and any Widevine CDM
    # NOT shipped.
    layout_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "d=/usr/share/playwright-browsers/chromium-%{revision}; case \"$(uname -m)\" in x86_64) i=chrome-linux64 ;; *) i=chrome-linux-arm64; test -x \"$d/chrome-linux/chrome\" ;; esac && test -x \"$d/$i/chrome\" && test -e \"$d/INSTALLATION_COMPLETE\" && test ! -e \"$d/$i/libqt5_shim.so\" && test ! -e \"$d/$i/libqt6_shim.so\" && ! find \"$d/\" -iname '*widevine*' | grep -q ."],
        ],
      } | Test,
  },
} | BuildSpec
