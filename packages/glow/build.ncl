let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "3.0.0" in
{
  name = "glow",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/charmbracelet/glow/v%{version}.tar.gz",
      sha256 = "18df6f3c09157021366b8c702b5badba405d37dbb42f132353eb50c1b0d3f464",
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
