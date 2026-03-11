let { standaloneTest, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let rust = import "../rust/build.ncl" in
let go = import "../go/build.ncl" in
let python = import "../python/build.ncl" in
let ruby = import "../ruby/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in
let git = import "../git/build.ncl" in
let curl = import "../curl/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.10" in
let dl_base = "https://github.com/oven-sh/bun/releases/download/bun-v%{version}" in
let { amd64_sha256, arm64_sha256 } = {
  amd64_sha256 = "f57bc0187e39623de716ba3a389fda5486b2d7be7131a980ba54dc7b733d2e08",
  arm64_sha256 = "fa5ecb25cafa8e8f5c87a0f833719d46dd0af0a86c7837d806531212d55636d3",
}
in
{
  name = "bun",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/oven-sh/bun/archive/refs/tags/bun-v%{version}.tar.gz",
      sha256 = "c017a59d908e0913da63c761e64bc525518d0271a54e30aae0fa426a4c840611",
      extract = true,
      strip_prefix = "bun-bun-v%{version}",
    } | Source,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "%{dl_base}/bun-linux-x64.zip",
          sha256 = amd64_sha256,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "%{dl_base}/bun-linux-aarch64.zip",
          sha256 = arm64_sha256,
        } | Source,
    } target,
    base,
    toolchain,
    cmake,
    ninja,
    llvm,
    rust,
    go,
    python,
    ruby,
    perl,
    pkgconf,
    make,
    git,
    curl,
    automake,
    libtool,
  ],
  runtime_deps = [
    glibc,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    bun = { glob = "usr/bin/bun" } | OutputBin,
    bunx = { glob = "usr/bin/bunx" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      env_state_wiring = {
        env_var = "BUN_INSTALL_CACHE_DIR",
        prefix = "bun-cache",
      },
      source_provenance = {
        category = 'GithubRepo,
        owner = "oven-sh",
        repo = "bun",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/bun --version",

    eval =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "bun --eval 'console.log(1+1)' | grep -q '^2$'"],
        ],
      } | Test,
  },
} | BuildSpec
