let { Attrs, BuildSpec, Local, OutputBin, Source, .., } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.4" in
{
  name = "imgcatr",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/SilinMeng0510/imgcatr/v%{version}.tar.gz",
      sha256 = "8e59a4ad83d1b474372fb8c5c1f11f07c742ea9443c26a9f02a4465140026f0e",
      extract = true,
      strip_prefix = "imgcatr-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],

  cmd = "./build.sh",

  outputs = {
    imgcatr = { glob = "usr/bin/imgcatr" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "SilinMeng0510",
        repo = "imgcatr",
      },
    } | Attrs,
} | BuildSpec
