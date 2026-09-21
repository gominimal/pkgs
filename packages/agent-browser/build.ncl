let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let node = import "../node/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in

let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# chromium-headless-shell-bin, NOT chromium-bin. agent-browser runs headless
# by default (`--headed` is opt-in), and headless-shell is the only Chromium
# we can ship on arm64 at all:
#
#   * chromium-bin's arm64 leg came from Playwright's CDN, and Playwright
#     STOPPED building linux-arm64 — r1243 was the last one ever (re-verified
#     2026-09-18: r1243 -> 200, r1245/1250/1260/1270 -> 400). It is a dead
#     source, not a stale pin.
#   * Google publishes no open-source Chromium binary for linux-arm64 at all;
#     the chromium-browser-snapshots bucket is x64 ONLY (Linux_ARM64 -> 404),
#     which is why chromium-bin needed a third-party build in the first place.
#   * Chrome for Testing DOES build arm64, but the `chrome` bundle is branded
#     Google Chrome and ships libwidevinecdm.so — gominimal/inbox#284 ruled
#     that non-redistributable, and our cache redistributes.
#
#   chrome-headless-shell is the exception that clears all three: CfT builds
#   it for arm64, and it was PROVEN redistributable for pkgs#718 — zero
#   WidevineCdm entries on either arch and a LICENSE.headless_shell carrying
#   the Chromium BSD-3-Clause grant.
#
# WHAT THIS GIVES UP, deliberately. chrome-headless-shell is the separate,
# reduced headless binary, not the full browser running headless, so these
# agent-browser features do NOT work against it:
#
#   --extensions        (no extension support in headless-shell)
#   --headed            (there is no headed mode in this binary)
#   WebGPU screenshots  (upstream documents these as requiring headed)
#
# Accepted because agent-browser is driven by agents, not humans: nothing
# runs it expecting a visible UI, and no consumer uses extensions. If that
# changes, the path back is Debian's chromium (DFSG-free, Widevine-free, both
# arches at 153.0.8010.52-1) at the cost of a 47-library runtime closure —
# libpulse, libopenh264, libdav1d, libFLAC, libopus, libminizip and friends,
# which Debian links dynamically where Google's build bundles them.
#
# It still brings the chromium system-lib closure (alsa-lib, cairo, cups,
# nss, mesa, the X11 stack, eudev, liberation-fonts) transitively, so we
# declare only the pkg.
let chromium-headless-shell-bin = import "../chromium-headless-shell-bin/build.ncl" in

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
    node,
    pnpm,
  ],
  runtime_deps = [
    bash,
    node,
    glibc,
    chromium-headless-shell-bin,
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
  },
} | BuildSpec
