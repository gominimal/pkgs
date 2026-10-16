let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "10.5.0" in
{
  name = "fd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sharkdp/fd/v%{version}.tar.gz",
      sha256 = "e6d9e90730bf316101691e49d59cc02565278dc3779d33a77423801569484851",
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
