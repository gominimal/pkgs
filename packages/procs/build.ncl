let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.14.10" in
{
  name = "procs",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/dalance/procs/v%{version}.tar.gz",
      sha256 = "7b287ac253fd1d202b0ea6a9a8ba2ed97598cf8e7dfd539bd40e382c6dc6d350",
      extract = true,
      strip_prefix = "procs-%{version}",
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
    procs = { glob = "usr/bin/procs" } | OutputBin,
    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "dalance",
        repo = "procs",
      },
    } | Attrs,
} | BuildSpec
