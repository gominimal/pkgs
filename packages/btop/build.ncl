let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in

let version = "1.4.6" in
{
  name = "btop",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/aristocratos/btop/v%{version}.tar.gz",
      sha256 = "4beb90172c6acaac08c1b4a5112fb616772e214a7ef992bcbd461453295a58be",
      extract = true,
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [ncurses],
  cmd = "./build.sh",
  outputs = {
    btop = { glob = "usr/bin/btop" } | OutputBin,
    data = { glob = "usr/share/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "aristocratos",
        repo = "btop",
      },
    } | Attrs,
} | BuildSpec
