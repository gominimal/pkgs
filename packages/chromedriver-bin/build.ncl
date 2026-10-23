let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let nss = import "../nss/build.ncl" in
let nspr = import "../nspr/build.ncl" in
let glib = import "../glib/build.ncl" in
let libxcb = import "../libxcb/build.ncl" in
let dbus = import "../dbus/build.ncl" in
let chromium-headless-shell-bin = import "../chromium-headless-shell-bin/build.ncl" in

# ChromeDriver from Chrome for Testing, at the SAME version as
# chromium-headless-shell-bin (ChromeDriver refuses a browser of a
# different major). Lets Selenium-driven browser tests (Rails system
# tests, Capybara + selenium-webdriver) run against packaged binaries
# instead of Selenium Manager downloading an unpinned Chrome + driver
# (~400 MB) at test time. Point Selenium at them with SE_OFFLINE=true and
# the browser/driver paths (see the test below).
#
# Prebuilt (binary_from below) because ChromeDriver is built inside the
# Chromium tree with gn and Chromium's own toolchain, which pkgs does not
# build from source yet; it ships on the same footing as
# chromium-headless-shell-bin.
#
# License: the CfT chromedriver zip carries LICENSE.chromedriver, the
# Chromium BSD-3-Clause grant, with no proprietary terms (unlike the full
# CfT `chrome` bundle, which ships Widevine). Re-checked at 156.0.8078.47.
#
# The version is NOT pinned here: it is chromium-headless-shell-bin's
# `upstream_version`, so the pair cannot drift. Bumping the browser changes
# the URLs below, so the two sha256s must be updated in the same change.
# A stale sha256 does NOT fail the fetch: sources are content-addressed, so
# the old zip is served from the store under its hash and the OLD driver
# gets built (pkgs#1003). The `matches_browser` test below is what catches
# it; pkgmgr's chromium updater re-pins both hashes with the browser.
let browser_version = chromium-headless-shell-bin.attrs.upstream_version in
{
  name = "chromedriver-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chromedriver-linux64.zip",
          sha256 = "2a5024610c53f340a1aaa5d9a3e2a4fa448be7d71cca5238bd8c3c7f16181df4",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chromedriver-linux-arm64.zip",
          sha256 = "5fe7ab694afa8258bb1b403facdf19c35de5ef30ec8a815aa01575f8c6d14ab6",
        } | Source,
    } target,
    base,
    unzip,
  ],
  # DT_NEEDED of the 156.0.8078.47 binaries: libc/libdl/libpthread/libm,
  # libgcc_s, glib, nspr, nss, libxcb, and libdbus-1 on amd64 only.
  runtime_deps =
    [
      glibc,
      subsetOf gcc ["libgcc"],
      nss,
      nspr,
      glib,
      libxcb,
    ]
    @ match {
      { arch = 'Amd64, .. } => [dbus],
      { arch = 'Arm64, .. } => [],
    } target,
  cmd = "./build.sh",
  outputs = {
    chromedriver = { glob = "usr/bin/chromedriver" } | OutputBin,
    licenses = { glob = "usr/share/licenses/chromedriver/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = browser_version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "GoogleChromeLabs",
        repo = "chrome-for-testing",
      },
      binary_from =
        match {
          { arch = 'Amd64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chromedriver-linux64.zip",
          { arch = 'Arm64, .. } => "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chromedriver-linux-arm64.zip",
        } target,
    } | Attrs,
  tests = {
    # Explicit argv + base: the string form of standaloneTest runs under a
    # shell, and this package (unlike headless-shell's wrapper) ships none.
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/chromedriver", "--version"]],
      } | Test,
    # The driver must report the same version as the packaged browser.
    matches_browser =
      {
        class = 'Standalone,
        test_deps = [base, chromium-headless-shell-bin],
        cmds = [
          ["/bin/bash", "-c", "d=$(/bin/chromedriver --version | awk '{print $2}'); b=$(/bin/chromium-headless-shell --version | grep -oE '[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+'); test \"$d\" = \"$b\" && test \"$d\" = %{browser_version}"],
        ],
      } | Test,
  },
} | BuildSpec
