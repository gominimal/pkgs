let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let curl = import "../curl/build.ncl" in
let gh = import "../gh/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in

# chromium-bin provides the browser Puppeteer drives (its full `chromium`,
# run in new headless mode) and its system-lib closure (cairo, fontconfig,
# freetype, harfbuzz, the X11 stack, mesa, nss, etc.) transitively, so we
# declare it directly rather than a per-system-lib runtime_dep list.
#
# NOT chromium-headless-shell-bin, for CVE-2026-111943 (eMudhra intermediate
# key compromise): chrome-headless-shell still trusts emSign ECC Root CA - G3
# and cannot read the CADistrustedCertificates policy that chromium-bin gets
# from chromium-policies (see chromium-headless-shell-bin's build.ncl and
# gominimal/pkgmgr-rs#1028). mmdc renders local input, but a diagram can still
# make the browser fetch https URLs (images in HTML labels, for example).
let chromium-bin = import "../chromium-bin/build.ncl" in

let version = "11.17.0" in
{
  name = "mermaid-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/mermaid-js/mermaid-cli/archive/refs/tags/%{version}.tar.gz",
      sha256 = "b5213dd373f09d0bfbc1ae839114246edecfe4e78248d50577f330af266d18ca",
    } | Source,
    base,
    curl,
    gh,
    node-lts,
  ],
  runtime_deps = [
    base,
    chromium-bin,
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
          ["/bin/bash", "-c", "test -x /bin/chromium"],
          # CVE-2026-111943: mmdc must point Puppeteer at the full browser,
          # which reads the policy chromium-policies installs.
          ["/bin/bash", "-c", "grep -qx 'export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium' /bin/mmdc"],
          ["/bin/bash", "-c", "grep -q CADistrustedCertificates /etc/chromium/policies/managed/ca-distrusted-certificates.json"],
          ["/bin/bash", "-c", "/bin/mmdc --help | grep -q 'mermaid'"],
        ],
      } | Test,
    # End-to-end mmdc render is a manual smoketest (PR test plan), not a
    # standalone test — `mmdc -i ... -o ...` fails inside `min check`'s
    # test sandbox even though `agent-browser open` (same chromium-bin
    # browser, different sandbox-internal behavior) passes there
    # and mmdc itself works in a normal session env. The runner
    # swallows stdout/stderr on failing tests so the actual error is
    # uninspectable. chromium-bin's launch_check already proves the
    # headless engine renders end-to-end in that same sandbox, and
    # install_check verifies mmdc's wrapper resolves to that working binary.
  },
} | BuildSpec
