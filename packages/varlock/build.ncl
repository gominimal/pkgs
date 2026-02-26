let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in

let version = "0.2.3" in
{
  name = "varlock",
  build_deps = [
    { file = "build.sh" } | Local,
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-staging-archives/dmno-dev/varlock/varlock-linux-x64-%{version}.tar.gz",
          sha256 = "b7a6cb07507105cac70e847adbf8fbe462f3a91f5376f564458e5c0d77bf0f96",
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-staging-archives/dmno-dev/varlock/varlock-linux-arm64-%{version}.tar.gz",
          sha256 = "0ec5d782dd0254f511aed3a2a7a3403a14d0bab4ed8947c35b29bc1d3543cbe9",
        } | Source,
    } target,
    base,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    varlock = { glob = "usr/bin/varlock" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "dmno-dev",
        repo = "varlock",
      },
    } | Attrs,

  tests.smoketest = standaloneTest "/bin/varlock --version",
} | BuildSpec
