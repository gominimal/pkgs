let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let version = "0.14.2" in
{
  name = "typst",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/typst/typst/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "70a56445020ca05efc571c7b07a1a9f52eb93842d420518693c077ae74e54142",
      extract = true,
      strip_prefix = "typst-%{version}",
    } | Source,
    base,
    rust,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    openssl,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    typst = { glob = "usr/bin/typst" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "typst",
        repo = "typst",
      },
    } | Attrs,
} | BuildSpec
