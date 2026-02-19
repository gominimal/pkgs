let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.23.4" in
{
  name = "eza",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/eza-community/eza/v%{version}.tar.gz",
      sha256 = "9fbcad518b8a2095206ac385329ca62d216bf9fdc652dde2d082fcb37c309635",
      extract = true,
      strip_prefix = "eza-%{version}",
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
    eza = { glob = "usr/bin/eza" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "eza-community",
        repo = "eza",
      },
    } | Attrs,
} | BuildSpec
