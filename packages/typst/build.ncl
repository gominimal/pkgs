let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let version = "0.15.1" in
{
  name = "typst",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/typst/typst/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "c07909e01a2a6941e52c9b616e48c209c755eed416d62bcf5583c37a4aca01a3",
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
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "typst",
        repo = "typst",
      },
    } | Attrs,
} | BuildSpec
