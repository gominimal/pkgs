let { Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.21.7" in
{
  name = "crane",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/google/go-containerregistry/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "4fa695c6a1f79793598d804cab380a3ba4f03539c0dbd4f0b9f38cdaf175ef3b",
      extract = true,
      strip_prefix = "go-containerregistry-%{version}",
    } | Source,
    base,
    go,
    toolchain,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    crane = { glob = "usr/bin/crane" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      repology_project = "go-containerregistry",
      source_provenance = {
        category = 'GithubRepo,
        owner = "google",
        repo = "go-containerregistry",
      },
    } | Attrs,
} | BuildSpec
