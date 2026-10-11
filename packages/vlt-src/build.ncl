# EXPERIMENT (vlt-from-source-exp): vlt built from source with no prebuilt vlt,
# esbuild or wasm in the chain, rooted in our node / go (hex0-rooted toolchain).
let { standaloneTest, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let node-lts = import "../node-lts/build.ncl" in
let go = import "../go/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
{
  name = "vlt-src",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "gen-deps.mjs" } | Local,
    # vlt's own source at the release tag
    {
      url = "https://github.com/vltpkg/vltpkg/archive/refs/tags/v1.3.7.tar.gz",
      sha256 = "c8dd06a1cf4520b76c4f8a83102cd6bdd11d1d8841889fabc51003bfdf3a0a74",
      extract = true,
      strip_prefix = "vltpkg-1.3.7",
    } | Source,
    # esbuild at the exact version vlt's bundler pins (infra/build: ^0.27.1 -> 0.27.7),
    # built from source with our go instead of npm's prebuilt @esbuild/<platform>
    {
      url = "https://github.com/evanw/esbuild/archive/refs/tags/v0.27.7.tar.gz",
      sha256 = "a2569028ce53f06531794e67388e760b343a1d5e77cef446a6ec07eeb96137f0",
      extract = true,
    } | Source,
    # the published npm tarball, ONLY to diff our build against (never installed)
    {
      url = "https://registry.npmjs.org/vlt/-/vlt-1.3.7.tgz",
      sha256 = "5195a4984473a35429a322165f493b5c1d45668bcd7b239ac8db6d839100fedc",
    } | Source,
    base,
    node-lts,
    go,
  ],
  runtime_deps = [coreutils, node-lts],
  needs = { dns = {}, internet = {} } | Needs,
  cmd = "./build.sh",
  outputs = {
    vlt = { glob = "usr/bin/vlt" } | OutputBin,
    vlr = { glob = "usr/bin/vlr" } | OutputBin,
    vlx = { glob = "usr/bin/vlx" } | OutputBin,
    libexec = { glob = "usr/libexec/vlt/**", allow_executable = true } | OutputData,
    report = { glob = "usr/share/vlt-src/**" } | OutputData,
  },
  tests = {
    smoketest = standaloneTest "/usr/bin/vlt --version",
    version_is_exact =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/bash", "-c", "test \"$(/usr/bin/vlt --version)\" = 1.3.7"]],
      } | Test,
    reads_a_manifest =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/bash", "-c", "d=/tmp/vs; mkdir -p $d; cd $d; printf '{\"name\":\"from-source\",\"version\":\"9.9.9\"}' > package.json; test \"$(VLT_TELEMETRY=0 /usr/bin/vlt pkg get name)\" = '\"from-source\"'"]],
      } | Test,
  },
} | BuildSpec
