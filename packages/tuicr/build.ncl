let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.27.0" in
{
  name = "tuicr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/agavra/tuicr/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "420f72b7ffc6e40db50383719dbec162fa712130c7a7d83c21cd07d504dd59e7",
      extract = true,
      strip_prefix = "tuicr-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  needs = {
    dns = {},
    internet = {},
  },

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    tuicr = { glob = "usr/bin/tuicr" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "agavra",
        repo = "tuicr",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "tuicr --version"],
          ["/bin/bash", "-c", "tuicr --help"],
        ],
      } | Test,
  },
} | BuildSpec
