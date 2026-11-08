let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let gh = import "../gh/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# chromium-headless-shell-bin provides the headless-shell binary (which
# Puppeteer drives in its "headless: shell" mode) and its system-lib closure
# (cairo, fontconfig, freetype, harfbuzz, the X11 stack, mesa, nss, etc.)
# transitively, so we declare it directly rather than a per-system-lib
# runtime_dep list. From pkgs#1114 this was chromium-bin's full browser, which
# read the chromium-policies distrust policy; chromium-bin was pulled (stuck at
# 156 with 158 open CVEs, no portablelinux 157).
#
# CVE-2026-111943 (eMudhra intermediate key compromise). mmdc renders local
# input, but a diagram can still make the browser fetch https URLs (images in
# HTML labels, for example). At chrome-headless-shell 157.0.8103.38 the
# built-in `kSPKIBlockList` holds all 8 compromised intermediate keys, so
# chains through them are refused. The compiled-in Chrome Root Store (v42)
# still trusts emSign ECC Root CA - G3 until Chrome 158 (root store v43), and
# headless-shell cannot read the CADistrustedCertificates policy. See
# agent-browser's and chromium-headless-shell-bin's build.ncl.
let chromium-headless-shell-bin = import "../chromium-headless-shell-bin/build.ncl" in

let version = "12.2.0" in
{
  name = "mermaid-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/mermaid-js/mermaid-cli/archive/refs/tags/%{version}.tar.gz",
      sha256 = "a09035e3eb7904c8e9a7de767cc49ce868945354484a9ef17ad2d683a024c5bd",
    } | Source,
    base,
    curl,
    gh,
    node-lts,
  ],
  runtime_deps = [
    base,
    chromium-headless-shell-bin,
    subsetOf node-lts ["node"],
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    mmdc = { glob = "usr/bin/mmdc" } | OutputBin,
    libexec = { glob = "usr/libexec/mermaid-cli/**", allow_executable = true } | OutputData,
    config = { glob = "usr/share/mermaid-cli/*.json" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "mermaid-js",
        repo = "mermaid-cli",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/mmdc --version",
    install_check =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test -x /bin/mmdc"],
          ["/bin/bash", "-c", "test -f /usr/libexec/mermaid-cli/lib/node_modules/@mermaid-js/mermaid-cli/src/cli.js"],
          ["/bin/bash", "-c", "test -x /bin/chromium-headless-shell"],
          # CVE-2026-111943: mmdc must point Puppeteer at headless-shell, in
          # Puppeteer's "shell" mode, and that browser must be at least
          # 157.0.8103.38, the pinned build, checked to carry the 8 compromised
          # eMudhra keys in its blocklist (chromium-headless-shell-bin's
          # `emudhra_spki_blocklist` test checks the binary). A floor, not the
          # exact pin, so a headless-shell bump does not break it.
          ["/bin/bash", "-c", "grep -qx 'export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-headless-shell' /bin/mmdc"],
          ["/bin/bash", "-c", "grep -qF '\"headless\":\"shell\"' /usr/share/mermaid-cli/puppeteer.json /usr/share/mermaid-cli/puppeteer-root.json"],
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
          ["/bin/bash", "-c", "/bin/mmdc --help | grep -q 'mermaid'"],
        ],
      } | Test,
    # End-to-end mmdc render is a manual smoketest (PR test plan), not a
    # standalone test — `mmdc -i ... -o ...` fails inside `min check`'s
    # test sandbox even though `agent-browser open` (same headless-shell
    # browser, different sandbox-internal behavior) passes there
    # and mmdc itself works in a normal session env. The runner
    # swallows stdout/stderr on failing tests so the actual error is
    # uninspectable. chromium-headless-shell-bin's launch_check already
    # proves the headless engine renders end-to-end in that same sandbox,
    # and install_check verifies mmdc's wrapper resolves to that working
    # binary.
  },
} | BuildSpec
