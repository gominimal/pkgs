let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in

let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# chromium-bin (its `chromium`, run headless), NOT chromium-headless-shell-bin.
#
# SECURITY, CVE-2026-111943 (eMudhra intermediate key compromise). agent-browser
# drives the browser against arbitrary, untrusted sites, so the browser's trust
# store is this package's trust store. chrome-headless-shell cannot be fixed
# from our side: its compiled-in Chrome Root Store still holds emSign ECC Root
# CA - G3, its blocklist lacks the 8 compromised keys, it gets no component
# updates, and it has no platform policy loader, so it cannot read the
# `CADistrustedCertificates` policy (see chromium-headless-shell-bin's build.ncl
# and gominimal/pkgmgr-rs#1028). No Chrome for Testing Stable carries the
# upstream fix yet (Stable 156.0.8078.47 is branch position 1706539; the fixes
# are main@{#1723080} and main@{#1723181}).
#
# chromium-bin's full browser does read the policy: it depends on
# chromium-policies, which installs /etc/chromium/policies/managed/
# ca-distrusted-certificates.json. Checked with the TLS trust harness
# (gominimal/pkgs#976): through headless-shell, `agent-browser open` loads every
# eMudhra test host; through chromium-bin it refuses them with
# net::ERR_CERT_AUTHORITY_INVALID and still loads letsencrypt.org.
#
# Both arches: chromium-bin is ungoogled-chromium-portablelinux (x86_64 and
# arm64, Stable, no Widevine). Running the full browser headless also brings
# back what headless-shell lacked (--extensions, --headed with a display).
# Return to headless-shell only once its pinned CfT Stable carries both
# upstream changes (the pkgmgr-rs#1028 trigger), if the smaller closure matters.
let chromium-bin = import "../chromium-bin/build.ncl" in

let version = "0.15.1" in
{
  name = "agent-browser",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vercel-labs/agent-browser/v%{version}.tar.gz",
      sha256 = "c30724a5fba1beb217ca5ce5ce9eee43b596dc72efe9ac29adb9af717795b6c9",
      extract = true,
      strip_prefix = "agent-browser-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
    rust,
    node-lts,
    pnpm,
  ],
  runtime_deps = [
    bash,
    subsetOf node-lts ["node"],
    glibc,
    chromium-bin,
  ],

  cmd = "./build.sh",

  outputs = {
    bin = { glob = "usr/bin/agent-browser" } | OutputBin,
    libexec = { glob = "usr/libexec/agent-browser/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel-labs",
        repo = "agent-browser",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/agent-browser --version",
    open_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # End-to-end: drive `agent-browser open` against a data: URL
          # and assert the page title appears in stdout. This exercises
          # the full path — Rust CLI launches the TS daemon, daemon
          # spawns chromium via /bin/chromium, navigates, returns
          # title.
          ["/bin/bash", "-c", "/bin/agent-browser open 'data:text/html,<title>agent-browser-open-ok</title>' | grep -q agent-browser-open-ok"],
        ],
      } | Test,
    # CVE-2026-111943: the daemon must launch chromium-bin's full browser,
    # which reads the CADistrustedCertificates policy. headless-shell cannot
    # (see the comment at the chromium-bin import).
    distrust_policy_wired =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "grep -qF -- '--executable-path /usr/bin/chromium \"' /usr/bin/agent-browser"],
          ["/bin/bash", "-c", "grep -q CADistrustedCertificates /etc/chromium/policies/managed/ca-distrusted-certificates.json"],
        ],
      } | Test,
  },
} | BuildSpec
