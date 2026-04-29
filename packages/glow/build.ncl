let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "2.1.2" in
{
  name = "glow",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/charmbracelet/glow/v%{version}.tar.gz",
      sha256 = "1b933139da1d08647bf5b3f112cab9548fdc2b40c056c7fa3d84d8706de5265a",
      extract = true,
      strip_prefix = "glow-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    glow = { glob = "usr/bin/glow" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "charmbracelet",
        repo = "glow",
      },
    } | Attrs,
} | BuildSpec
