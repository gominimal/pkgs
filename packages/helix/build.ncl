let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let git = import "../git/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let helix-grammars = import "../helix-grammars/build.ncl" in

let version = "25.07.1" in
{
  name = "helix",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/helix-editor/helix/%{version}.tar.gz",
      sha256 = "27c8bc3eba46bc7bab1e3629c6b28ff94882eeff17366b3ea69cd8ceffba7541",
      extract = true,
      strip_prefix = "helix-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    git,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    gcc,
    helix-grammars,
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    hx = { glob = "usr/bin/hx" } | OutputBin,
    runtime = { glob = "usr/lib/helix/runtime/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MPL-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "helix-editor",
        repo = "helix",
      },
    } | Attrs,
  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "hx --version"],
          # `--health <lang>` prints "Tree-sitter parser: ✓" only when the
          # grammar .so from helix-grammars actually dlopens out of
          # HELIX_DEFAULT_RUNTIME, so this covers the runtime dir wiring too.
          ["/bin/bash", "-c", "hx --health rust | grep -q 'Tree-sitter parser:.*✓'"],
          # yaml's scanner is C++ — exercises the libstdc++ link as well.
          ["/bin/bash", "-c", "hx --health yaml | grep -q 'Tree-sitter parser:.*✓'"],
        ],
      } | Test,
  },
} | BuildSpec
