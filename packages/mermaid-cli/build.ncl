let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let alsa-lib = import "../alsa-lib/build.ncl" in
let at-spi2-core = import "../at-spi2-core/build.ncl" in
let atk = import "../atk/build.ncl" in
let base = import "../base/build.ncl" in
let bash = import "../bash/build.ncl" in
let cairo = import "../cairo/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let cups = import "../cups/build.ncl" in
let curl = import "../curl/build.ncl" in
let dbus = import "../dbus/build.ncl" in
let eudev = import "../eudev/build.ncl" in
let expat = import "../expat/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let gh = import "../gh/build.ncl" in
let glib = import "../glib/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let harfbuzz = import "../harfbuzz/build.ncl" in
let liberation-fonts = import "../liberation-fonts/build.ncl" in
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
let mesa = import "../mesa/build.ncl" in
let node = import "../node/build.ncl" in
let nspr = import "../nspr/build.ncl" in
let nss = import "../nss/build.ncl" in
let pango = import "../pango/build.ncl" in
let python = import "../python/build.ncl" in

let version = "11.12.0" in
{
  name = "mermaid-cli",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/mermaid-js/mermaid-cli/archive/refs/tags/%{version}.tar.gz",
      sha256 = "1911d5f96546b7278cb734b6f4b388b679bc0b36d6c37ba8de1a032d5a9ae6af",
    } | Source,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://playwright.azureedge.net/builds/chromium/1148/chromium-headless-shell-linux.zip",
          sha256 = "43c8f1e29e089d9765ed83083ebbcaa7c7fe582aa762d0678f88838b55d92f63",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://playwright.azureedge.net/builds/chromium/1148/chromium-headless-shell-linux-arm64.zip",
          sha256 = "be65413764b753fb73187dd1d760cc6622730f2a4da23923eef76973c17fb25c",
        } | Source,
    } target,
    base,
    curl,
    gh,
    node,
    python,
  ],
  runtime_deps = [
    alsa-lib,
    at-spi2-core,
    atk,
    bash,
    cairo,
    coreutils,
    cups,
    dbus,
    eudev,
    expat,
    fontconfig,
    freetype,
    fribidi,
    gcc,
    glib,
    glibc,
    harfbuzz,
    liberation-fonts,
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
    mesa,
    node,
    nspr,
    nss,
    pango,
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
    libexec = { glob = "usr/lib/node_modules/**", allow_executable = true } | OutputData,
    chromium = { glob = "usr/share/mermaid-cli/chromium/**", allow_executable = true } | OutputData,
    config = { glob = "usr/share/mermaid-cli/*.json" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
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
          ["/bin/bash", "-c", "test -f /usr/lib/node_modules/@mermaid-js/mermaid-cli/src/cli.js"],
          ["/bin/bash", "-c", "test -x /usr/share/mermaid-cli/chromium/headless_shell"],
          ["/bin/bash", "-c", "! ldd /usr/share/mermaid-cli/chromium/headless_shell | grep -q 'not found'"],
          ["/bin/bash", "-c", "/bin/mmdc --help | grep -q 'mermaid'"],
        ],
      } | Test,
  },
} | BuildSpec
