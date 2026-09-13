let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.20" in
{
  name = "leangz",
  # `leantar` + `leangz`: the (de)compressor for Lean `.olean` build artifacts
  # (`.ltar`). Official Lean releases bundle `leantar` in `bin/`; a from-source
  # lean build does not produce it, and Mathlib's build-cache tool
  # (`lake exe cache get`) refuses to run without it:
  #   leantar not found in Lean sysroot. This toolchain may predate nightly-2026-03-09.
  # The cache tool looks for `<lean prefix>/bin/leantar`, i.e. /usr/bin/leantar.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/digama0/leangz/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "46b1b7aea6905ace2f06083143bdc8e782643517c62d19751d8933620fd44816",
      extract = true,
      strip_prefix = "leangz-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
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
    leantar = { glob = "usr/bin/leantar" } | OutputBin,
    leangz = { glob = "usr/bin/leangz" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "digama0",
        repo = "leangz",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "leantar --version"],
        ],
      } | Test,
  },
} | BuildSpec
