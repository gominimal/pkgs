let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "10.4.2" in
{
  name = "fd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sharkdp/fd/v%{version}.tar.gz",
      sha256 = "3a7e027af8c8e91c196ac259c703d78cd55c364706ddafbc66d02c326e57a456",
      extract = true,
      strip_prefix = "fd-%{version}",
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
    fd = { glob = "usr/bin/fd" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sharkdp",
        repo = "fd",
      },
    } | Attrs,
} | BuildSpec
