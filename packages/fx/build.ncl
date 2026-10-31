let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let zig = import "../zig/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# fx — vercel-labs/fx, an experimental AI coding-agent harness written in Zig
# (Apache-2.0). Source build via our zig toolchain, mirroring the opencode
# harness. build.zig.zon declares NO dependencies and `minimum_zig_version =
# "0.17.0"` (fx moved to zig 0.17 in 0.0.14), so `zig build` is fully hermetic — no network,
# and `readGitCommit` falls back to "unknown" without a .git dir.
let version = "0.0.16" in
{
  name = "fx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vercel-labs/fx/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "545d95702ad2a0ce811af9261b7fe2daa1a4e6394ff6de54f4020e419d333079",
      extract = true,
      strip_prefix = "fx-%{version}",
    } | Source,
    base,
    zig,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    fx = { glob = "usr/bin/fx" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      build_cost_multiple = 2,
      source_provenance = {
        category = 'GithubRepo,
        owner = "vercel-labs",
        repo = "fx",
      },
    } | Attrs,

  tests = {
    # Not named `version`: Nickel records are recursive, so a field called
    # `version` would shadow the version binding the command interpolates.
    reports_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Proves the binary runs and the embedded app_version (read from
          # src/main.zig at build time) is the release we packaged. Offline:
          # `--version` (added by 0.0.15) needs no gateway or API key. The bare
          # version is matched, so a `v` prefix either way passes.
          ["/bin/bash", "-c", "fx --version 2>&1 | grep -qF '%{version}'"],
        ],
      } | Test,
  },
} | BuildSpec
