let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "5.59.0" in
{
  name = "railway",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/railwayapp/cli/v%{version}.tar.gz",
      sha256 = "83d257bc559f6d6081b113d4e61af77f93e584ff792b2bac6a53fb4fdd1e349d",
      extract = true,
      strip_prefix = "cli-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
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
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "railwayapp",
        repo = "cli",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
