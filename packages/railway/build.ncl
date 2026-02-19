let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.30.2" in
{
  name = "railway",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/railwayapp/cli/v%{version}.tar.gz",
      sha256 = "6bf10cdc6b57d025ee846c948633d9f596ea7d5842ed8edaa4e7af9fd58efd31",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc, # TODO, weird
  ],

  cmd = "./build.sh",

  outputs = {
    railway = { glob = "usr/bin/railway" } | OutputBin,
  },
  attrs =
    {
      # Wire up Railway's global state directory.
      env_dir_mappings = [{ read_only = false, path = "~/.railway", class = 'State }],
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "railwayapp",
        repo = "cli",
      },
    } | Attrs,
} | BuildSpec
