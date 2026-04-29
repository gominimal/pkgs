let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.72.0" in
{
  name = "fzf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/junegunn/fzf/v%{version}.tar.gz",
      sha256 = "ca5ce083cec5187503ceb96d837c20d8efde85f03e62bba3a8890f8da526f2fc",
      extract = true,
      strip_prefix = "fzf-%{version}",
    } | Source,
    base,
    go,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    fzf = { glob = "usr/bin/fzf" } | OutputBin,

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "junegunn",
        repo = "fzf",
      },
    } | Attrs,
} | BuildSpec
