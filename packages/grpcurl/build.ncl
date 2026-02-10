let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.9.3" in
{
  name = "grpcurl",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/fullstorydev/grpcurl/v%{version}.tar.gz",
      sha256 = "bb555087f279af156159c86d4d3d5dd3f2991129e4cd6b09114e6851a679340d",
      extract = true,
      strip_prefix = "grpcurl-%{version}",
    } | Source,
    base,
    go,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    grpcurl = { glob = "usr/bin/grpcurl" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "grpcurl",
    } | Attrs,
} | BuildSpec
