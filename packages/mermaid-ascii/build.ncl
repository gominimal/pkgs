let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.0" in
{
  name = "mermaid-ascii",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/AlexanderGrooff/mermaid-ascii/%{version}.tar.gz",
      sha256 = "bd5081a926914c7b156b5222ee1f71bfb974ba3a3df34a9f8c82c1418caf617b",
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
} | BuildSpec
