let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.9.4" in
{
  name = "grpcurl",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/fullstorydev/grpcurl/v%{version}.tar.gz",
      sha256 = "bea899ba2f483a951bf40aa05d41e069dd2f7bfe52d2a229717abfdb5620cb7c",
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
      license_spdx = "MIT",
      repology_project = "grpcurl",
      source_provenance = {
        category = 'GithubRepo,
        owner = "fullstorydev",
        repo = "grpcurl",
      },
    } | Attrs,
} | BuildSpec
