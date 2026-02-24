let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.0" in
{
  name = "weathr",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/Veirt/weathr/v%{version}.tar.gz",
      sha256 = "88eebe264fc874be24b0f250d19b48eaecf050b268af6f333ec1ce6da13a30f0",
      extract = true,
      strip_prefix = "weathr-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    weathr = { glob = "usr/bin/weathr" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "Veirt",
        repo = "weathr",
      },
    } | Attrs,
} | BuildSpec
