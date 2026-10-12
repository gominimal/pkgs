let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.74.5" in
{
  name = "fzf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/junegunn/fzf/v%{version}.tar.gz",
      sha256 = "5529d08897b85ae773695787c811ff9c9eeee32419c8a297fa1dbe586ed0a27e",
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
