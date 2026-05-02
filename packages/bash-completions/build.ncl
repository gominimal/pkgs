let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in

let version = "2.17.0" in
{
  name = "bash-completions",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/scop/bash-completion/releases/download/%{version}/bash-completion-%{version}.tar.xz",
      sha256 = "dd9d825e496435fb3beba3ae7bea9f77e821e894667d07431d1d4c8c570b9e58",
    } | Source,
    base,
    make,
    tar,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    etcs = { glob = "etc/**" } | OutputData,

    completions = { glob = "usr/share/bash-completion/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "scop",
        repo = "bash-completion",
      },
    } | Attrs,
} | BuildSpec
