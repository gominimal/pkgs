let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.6.2" in
{
  name = "mermaid-ascii",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/AlexanderGrooff/mermaid-ascii/%{version}.tar.gz",
      sha256 = "bff61527c34b58c51aa34e1f670e6ebd5ca35728f6f99556cd3d904896ec428d",
      extract = true,
      strip_prefix = "mermaid-ascii-%{version}",
    } | Source,
    base,
    go,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    mermaid-ascii = { glob = "usr/bin/mermaid-ascii" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "AlexanderGrooff",
        repo = "mermaid-ascii",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/mermaid-ascii --help",
  },
} | BuildSpec
