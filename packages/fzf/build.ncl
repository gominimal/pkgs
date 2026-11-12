let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.75.0" in
{
  name = "fzf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/junegunn/fzf/v%{version}.tar.gz",
      sha256 = "165f6e0c1b9ba082346233681e3f1d1374e37f9fd3c1d7b6dfe09659ab893faa",
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
    fzf-tmux = { glob = "usr/bin/fzf-tmux", allow_missing_interpreter = true } | OutputBin,

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

  tests = {
    smoketest = standaloneTest "/usr/bin/fzf --version",
  },
} | BuildSpec
