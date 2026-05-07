let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let rust = import "../rust/build.ncl" in
let node = import "../node/build.ncl" in
let pnpm = import "../pnpm/build.ncl" in

let bash = import "../bash/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# chromium-bin is the Playwright-revisioned prebuilt chromium pkg; see
# its build.ncl for why a prebuilt and the amd64/arm64 source story.
# It also brings the full chromium system-lib closure (alsa-lib, cairo,
# cups, nss, mesa, the X11 stack, eudev, liberation-fonts, etc.) as
# transitive runtime_deps, so we only declare the pkg directly.
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
    node,
    pnpm,
  ],
  runtime_deps = [
    bash,
    node,
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
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel-labs",
        repo = "agent-browser",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/agent-browser --version",
  },
} | BuildSpec
