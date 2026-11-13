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

# chromium-headless-shell-bin (Chrome for Testing `chrome-headless-shell`,
# Stable, x86_64 and arm64). It brings the Chromium system-lib closure
# (alsa-lib, cairo, cups, nss, mesa, the X11 stack, eudev, liberation-fonts)
# transitively, so we declare only the pkg.
#
# From pkgs#1114 this was chromium-bin (ungoogled-chromium-portablelinux, the
# full browser run headless), which read the chromium-policies distrust
# policy. chromium-bin was pulled: it was stuck at 156 with 158 open CVEs
# (30 Critical) because portablelinux had not released 157. headless-shell is
# a separate, reduced headless binary, so these agent-browser features do NOT
# work against it:
#
#   --extensions        (no extension support in headless-shell)
#   --headed            (there is no headed mode in this binary)
#   WebGPU screenshots  (upstream documents these as requiring headed)
#
# SECURITY, CVE-2026-111943 (eMudhra intermediate key compromise). agent-browser
# drives the browser against arbitrary, untrusted sites, so the browser's trust
# store is this package's trust store. On Linux, Chromium verifies only against
# its compiled-in Chrome Root Store (`chrome_root_store_only`,
# net/features.gni), so /etc/ssl/certs does not apply to the browser. At
# chrome-headless-shell 157.0.8103.38:
#   * BLOCKED: `kSPKIBlockList` (net/cert/cert_verify_proc_blocklist.inc)
#     holds all 8 compromised intermediate keys, so a chain through any of
#     them is refused whatever root it reaches. chromium-headless-shell-bin's
#     `emudhra_spki_blocklist` test checks the shipped binary for them.
#   * STILL TRUSTED until Chrome 158: the compiled-in root store is
#     version_major 42 and still holds emSign ECC Root CA - G3 (86a1ecba...).
#     Chrome Root Store v43 removes it, and 158.0.8127.18 carries v43. Until
#     then, a certificate under that root that does not chain through one of
#     the 8 keys still validates.
#   * headless-shell has no platform policy loader, so it cannot read the
#     `CADistrustedCertificates` policy chromium-policies installs (see
#     chromium-headless-shell-bin's build.ncl).
# The TLS trust harness (gominimal/pkgs#976) result for headless-shell (every
# eMudhra test host loaded) predates 157 and has not been re-run on it.
# Bumping chromium-headless-shell-bin to 158 closes the root gap.
let chromium-headless-shell-bin = import "../chromium-headless-shell-bin/build.ncl" in

let version = "0.42.0" in
{
  name = "agent-browser",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/vercel-labs/agent-browser/v%{version}.tar.gz",
      sha256 = "f2533ef11197a88300efac00e8cc76b8efbeefd1e0532dfabcd50dcf37000e8c",
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
    chromium-headless-shell-bin,
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
      # The binary compiles in more than agent-browser's own Apache-2.0 code
      # (checked for 0.41.1; dual-licensed parts counted at MIT/Apache-2.0):
      #   MPL-2.0       axe-core 4.12.1 (cli/src/native/a11y/axe.min.js, include_str!),
      #                 and the option-ext crate (via dirs)
      #   MIT, ISC      axe-core's bundled third-party code (LICENSE-axe-core-THIRD-PARTY.txt);
      #                 React DevTools installHook.js (cli/src/native/react)
      #   BSD-3-Clause  Chrome DevTools Protocol JSON (cli/cdp-protocol, codegen in build.rs);
      #                 subtle, exr, ravif crates
      #   OFL-1.1       Geist, which next/font self-hosts into the embedded dashboard
      #   dashboard JS  next, react, radix-ui, ai, streamdown, d3, ... (MIT, ISC, Apache-2.0,
      #                 BSD-3-Clause)
      #   Rust crates   (cli/Cargo.lock) mostly MIT OR Apache-2.0, plus ISC (ring,
      #                 rustls-webpki, untrusted), Unicode-3.0 (icu_*, zerovec, ...),
      #                 BSD-2-Clause (rav1e), Zlib (zlib-rs, foldhash) and
      #                 CDLA-Permissive-2.0 (webpki-roots' root list)
      license_spdx = "Apache-2.0 AND MPL-2.0 AND MIT AND ISC AND BSD-2-Clause AND BSD-3-Clause AND Unicode-3.0 AND Zlib AND CDLA-Permissive-2.0 AND OFL-1.1",
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
    # No Node runtime or node_modules ships any more; the embedded code's
    # licence texts do.
    layout =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test ! -e /usr/libexec/agent-browser/node_modules && test ! -e /usr/bin/node"],
          ["/bin/bash", "-c", "grep -q 'Mozilla Public License' /usr/share/licenses/agent-browser/LICENSE-axe-core.txt"],
          ["/bin/bash", "-c", "test -s /usr/share/licenses/agent-browser/LICENSE-axe-core-THIRD-PARTY.txt"],
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
          # /usr/bin/chromium-headless-shell (the wrapper's
          # AGENT_BROWSER_EXECUTABLE_PATH), navigates to a data: URL, and
          # prints the page title.
          # TEST-ONLY --no-sandbox: the build-bot's test sandbox has no
          # unprivileged user namespaces, so Chromium aborts with "No usable
          # sandbox!" (pkgs#1269 build-bot run, both arches).
          # chromium-headless-shell-bin's own launch test passes the same
          # flags. The shipped wrapper keeps Chromium's sandbox;
          # AGENT_BROWSER_ARGS (comma-separated launch args, cli flags.rs) is
          # set only inside these test shells.
          ["/bin/bash", "-c", "export AGENT_BROWSER_ARGS=--no-sandbox,--disable-gpu,--disable-dev-shm-usage; /bin/agent-browser open 'data:text/html,<title>agent-browser-open-ok</title>' | grep -q agent-browser-open-ok"],
          # A follow-up command reaches the same daemon and page. One shell:
          # the daemon does not outlive a test command.
          ["/bin/bash", "-c", "set -o pipefail; export AGENT_BROWSER_ARGS=--no-sandbox,--disable-gpu,--disable-dev-shm-usage; /bin/agent-browser open 'data:text/html,<title>agent-browser-reuse-ok</title>' >/dev/null && /bin/agent-browser get title | grep -q agent-browser-reuse-ok; rc=$?; /bin/agent-browser close >/dev/null; exit $rc"],
        ],
      } | Test,
    # CVE-2026-111943: the daemon must launch chromium-headless-shell-bin's
    # browser, at 157.0.8103.38 or later: the pinned build, checked to carry the
    # 8 compromised eMudhra keys in its blocklist. That package's
    # `emudhra_spki_blocklist` test checks the keys in the binary; the emSign
    # ECC G3 root stays trusted until 158 (see the comment at the import).
    # A floor, not the exact pin, so a headless-shell bump does not break it.
    # And the CLI's own HTTPS must use the system store, not its compiled-in
    # webpki-roots.
    browser_wired =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "grep -qF 'AGENT_BROWSER_EXECUTABLE_PATH:-/usr/bin/chromium-headless-shell}' /usr/bin/agent-browser"],
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              floor=157.0.8103.38
              v=$(/usr/bin/chromium-headless-shell --version | grep -oE '[0-9]+(\.[0-9]+){3}' | head -n1)
              test -n "$v"
              test "$(printf '%s\n' "$floor" "$v" | sort -V | head -n1)" = "$floor"
            "%,
          ],
          ["/bin/bash", "-c", "grep -qF 'AGENT_BROWSER_USE_SYSTEM_CA:-1}' /usr/bin/agent-browser"],
          ["/bin/bash", "-c", "test -s /etc/ssl/certs/ca-certificates.crt"],
        ],
      } | Test,
  },
} | BuildSpec
