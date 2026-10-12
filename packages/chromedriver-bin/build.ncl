let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let unzip = import "../unzip/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let nss = import "../nss/build.ncl" in
let nspr = import "../nspr/build.ncl" in
let glib = import "../glib/build.ncl" in
let libxcb = import "../libxcb/build.ncl" in
# The amd64 build also links libdbus-1 (the arm64 one does not).
let dbus = import "../dbus/build.ncl" in
let chromium-headless-shell-bin = import "../chromium-headless-shell-bin/build.ncl" in

# ChromeDriver from Chrome for Testing, pinned to the SAME version as
# chromium-headless-shell-bin so the two always match (ChromeDriver
# refuses a browser of a different major). Lets Selenium-driven browser
# tests (Rails system tests, Capybara + selenium-webdriver) run against
# packaged binaries instead of Selenium Manager downloading an unpinned
# Chrome + driver (~400 MB) at test time. Point Selenium at them with
# SE_OFFLINE=true and the browser/driver paths (see the test below).
#
# License: the CfT chromedriver zip carries LICENSE.chromedriver, the
# Chromium BSD-3-Clause grant, with no proprietary terms (unlike the full
# CfT `chrome` bundle, which ships Widevine). Verified at 153.0.8010.52; now 155.0.8059.39 (CfT hashes re-checked 2026-10-12).
#
# Bump `browser_version` together with chromium-headless-shell-bin.
let browser_version = "155.0.8059.39" in
{
  name = "chromedriver-bin",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux64/chromedriver-linux64.zip",
          sha256 = "a65f025c692e686ec2a21fa6b9639c69fa9813683a47af9cabf1ba0b1f453e42",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://storage.googleapis.com/chrome-for-testing-public/%{browser_version}/linux-arm64/chromedriver-linux-arm64.zip",
          sha256 = "e375914dc2ee52c38ffc6db4ee8276b462a2872f94ca458c18d787e0f761b129",
        } | Source,
    } target,
    base,
    unzip,
  ],
  runtime_deps = [
    glibc,
    gcc,
    nss,
    nspr,
    glib,
    libxcb,
    dbus,
  ],
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
