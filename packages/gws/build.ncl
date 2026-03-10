let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.11.0" in
{
  name = "gws",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/googleworkspace/cli/v%{version}.tar.gz",
      sha256 = "45fcf2eedfb94bf8a57f57fc00bdce68e2b83dcdfd593b56efbb8258ae085aac",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc,
  ],

  cmd = "./build.sh",

  outputs = {
    gws = { glob = "usr/bin/gws" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "googleworkspace",
        repo = "cli",
      },
    } | Attrs,
} | BuildSpec
