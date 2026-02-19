let { Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let git = import "../git/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "25.07.1" in
{
  name = "helix",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/helix-editor/helix/%{version}.tar.gz",
      sha256 = "27c8bc3eba46bc7bab1e3629c6b28ff94882eeff17366b3ea69cd8ceffba7541",
      extract = true,
      strip_prefix = "helix-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    git,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  runtime_deps = [
    glibc,
    gcc,
  ],

  cmd = "./build.sh",

  outputs = {
    hx = { glob = "usr/bin/hx" } | OutputBin,
    runtime = { glob = "usr/lib/helix/runtime/**" } | OutputData,
    grammars = { glob = "usr/lib/helix/runtime/grammars/*.so" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "helix-editor",
        repo = "helix",
      },
    } | Attrs,
} | BuildSpec
