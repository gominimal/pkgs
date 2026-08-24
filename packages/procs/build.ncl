let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.14.12" in
{
  name = "procs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/dalance/procs/v%{version}.tar.gz",
      sha256 = "f2fab583fe98a9ae9505c5eecf4f3d9d4ad9bcb5d478a8222d52c87aa1ac602e",
      extract = true,
      strip_prefix = "procs-%{version}",
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
    procs = { glob = "usr/bin/procs" } | OutputBin,
    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "dalance",
        repo = "procs",
      },
    } | Attrs,
} | BuildSpec
