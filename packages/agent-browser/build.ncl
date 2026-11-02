let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in
let ca-certificates = import "../ca-certificates/build.ncl" in

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

let version = "0.41.1" in
{
  name = "agent-browser",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vercel-labs/agent-browser/v%{version}.tar.gz",
      sha256 = "b3d9d60b8a38f05e0f9b4d84d9e0b6995c21df2eb963eefb703008682a69f3bb",
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
  # node-lts and pnpm build only the dashboard the binary embeds. The CLI is a
  # native Rust binary: 0.20.0 removed the Node.js daemon (upstream #754), and
  # the npm package's bin/agent-browser.js is just a launcher that picks the
  # per-platform binary. So node is no longer a runtime dep and no
  # node_modules ships.
  runtime_deps = [
    bash, # the /usr/bin/agent-browser wrapper
    glibc,
    chromium-bin,
    # The wrapper sets AGENT_BROWSER_USE_SYSTEM_CA=1: the CLI's own HTTPS
    # (`read`, `doctor`, plugins…) reads /etc/ssl/certs instead of its
    # compiled-in webpki-roots (pkgs AGENTS.md "Trust store").
    ca-certificates,
  ],

  cmd = "./build.sh",

  outputs = {
    # Wrapper: sets AGENT_BROWSER_EXECUTABLE_PATH / AGENT_BROWSER_USE_SYSTEM_CA
    # defaults, then execs the binary below (see build.sh).
    bin = { glob = "usr/bin/agent-browser" } | OutputBin,
    # The binary (with the dashboard, axe-core and the CDP protocol compiled
    # in) and the skills/ + skill-data/ trees it serves via `agent-browser
    # skills` and the MCP `skills_*` tools. It finds them relative to its own
    # canonical path, so they must stay beside bin/.
    libexec = { glob = "usr/libexec/agent-browser/**", allow_executable = true } | OutputData,
    licenses = { glob = "usr/share/licenses/agent-browser/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      # The binary compiles in more than agent-browser's own Apache-2.0 code:
      #   MPL-2.0       axe-core 4.12.1 (cli/src/native/a11y/axe.min.js, include_str!)
      #   MIT, ISC      axe-core's bundled third-party code (LICENSE-axe-core-THIRD-PARTY.txt)
      #   MIT           React DevTools installHook.js (cli/src/native/react)
      #   BSD-3-Clause  Chrome DevTools Protocol JSON (cli/cdp-protocol, codegen in build.rs)
      #   OFL-1.1       Geist font, self-hosted into the embedded dashboard by next/font
      #   dashboard JS  next, react, radix-ui, ai, streamdown, … (MIT / ISC / Apache-2.0)
      #   Rust crates   from cli/Cargo.lock (see the PR that bumped to 0.41.1 for the list)
      license_spdx = "Apache-2.0 AND MPL-2.0 AND MIT AND ISC AND BSD-3-Clause AND OFL-1.1",
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel-labs",
        repo = "agent-browser",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/agent-browser --version | grep -qx 'agent-browser %{version}'"],
        ],
      } | Test,
    # The skills lookup is relative to the binary's canonical path
    # (skills.rs find_package_root): a layout change breaks it silently, so
    # list them and require the bundled `core` skill.
    skills =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/bin/agent-browser skills list | grep -qw core"],
          ["/bin/bash", "-c", "/bin/agent-browser skills get core | grep -q agent-browser"],
        ],
      } | Test,
    # The real dashboard export is embedded, not cli/build.rs's placeholder.
    dashboard_embedded =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "grep -qa 'Observability dashboard for agent-browser' /usr/libexec/agent-browser/bin/agent-browser"],
          ["/bin/bash", "-c", "! grep -qa 'Dashboard not built' /usr/libexec/agent-browser/bin/agent-browser"],
        ],
      } | Test,
    open_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # End-to-end: the CLI starts its native daemon, which launches
          # chromium-bin's /usr/bin/chromium headless (the wrapper's
          # AGENT_BROWSER_EXECUTABLE_PATH), navigates to a data: URL, and
          # prints the page title.
          ["/bin/bash", "-c", "/bin/agent-browser open 'data:text/html,<title>agent-browser-open-ok</title>' | grep -q agent-browser-open-ok"],
          ["/bin/bash", "-c", "/bin/agent-browser get title | grep -q agent-browser-open-ok"],
          ["/bin/bash", "-c", "/bin/agent-browser close"],
        ],
      } | Test,
    # CVE-2026-111943: the daemon must launch chromium-bin's full browser,
    # which reads the CADistrustedCertificates policy. headless-shell cannot
    # (see the comment at the chromium-bin import). And the CLI's own HTTPS
    # must use the system store, not its compiled-in webpki-roots.
    distrust_policy_wired =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "grep -qF 'AGENT_BROWSER_EXECUTABLE_PATH:-/usr/bin/chromium}' /usr/bin/agent-browser"],
          ["/bin/bash", "-c", "grep -qF 'AGENT_BROWSER_USE_SYSTEM_CA:-1}' /usr/bin/agent-browser"],
          ["/bin/bash", "-c", "grep -q CADistrustedCertificates /etc/chromium/policies/managed/ca-distrusted-certificates.json"],
          ["/bin/bash", "-c", "test -s /etc/ssl/certs/ca-certificates.crt"],
        ],
      } | Test,
  },
} | BuildSpec
