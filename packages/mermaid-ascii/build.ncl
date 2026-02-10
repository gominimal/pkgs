let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.1.0" in
{
  name = "mermaid-ascii",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/AlexanderGrooff/mermaid-ascii/%{version}.tar.gz",
      sha256 = "28c8b9a5ff1e475518d2054384a08bf23bb372f2f21cd3a7a3a5ba97eecd552a",
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
  attrs.upstream_version = version,
} | BuildSpec
