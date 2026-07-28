let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "0.23.1" in
{
  name = "bandwhich",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/imsnif/bandwhich/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "aafb96d059cf9734da915dca4f5940c319d2e6b54e2ffb884332e9f5e820e6d7",
      extract = true,
      strip_prefix = "bandwhich-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    make,
  ],
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,
  cmd = "./build.sh",
  outputs = {
    bandwhich = { glob = "usr/bin/bandwhich" } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "imsnif", repo = "bandwhich" },
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
