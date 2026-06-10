let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.10.0" in
{
  name = "shellcheck",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "https://github.com/koalaman/shellcheck/releases/download/v%{version}/shellcheck-v%{version}.linux.x86_64.tar.xz",
          sha256 = "6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "https://github.com/koalaman/shellcheck/releases/download/v%{version}/shellcheck-v%{version}.linux.aarch64.tar.xz",
          sha256 = "324a7e89de8fa2aed0d0c28f3dab59cf84c6d74264022c00c22af665ed1a09bb",
        } | Source,
    } target,
    base,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    shellcheck = { glob = "usr/bin/shellcheck" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "koalaman",
        repo = "shellcheck",
      },
    } | Attrs,
} | BuildSpec
