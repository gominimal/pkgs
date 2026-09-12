let { Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let zig = import "../zig/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# fx — vercel-labs/fx, an experimental AI coding-agent harness written in Zig
# (Apache-2.0). Source build via our zig toolchain, mirroring the opencode
# harness. build.zig.zon declares NO dependencies and `minimum_zig_version =
# "0.16.0"` (exactly our zig), so `zig build` is fully hermetic — no network,
# and `readGitCommit` falls back to "unknown" without a .git dir.
let version = "0.0.7" in
{
  name = "fx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/vercel-labs/fx/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "bcbf3850b8e3ebcc1e8728104eec76242dd43399fe0c08b625887b2a6673427f",
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
    version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # Proves the binary runs and the embedded app_version (read from
          # src/main.zig at build time) is the release we packaged. Offline —
          # help needs no gateway / API key. fx has no `version` subcommand; the
          # banner rides the help output.
          ["/bin/bash", "-c", "fx --help 2>&1 | grep -q 'v0.0.7'"],
        ],
      } | Test,
  },
} | BuildSpec
