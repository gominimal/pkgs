let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "0.23.5" in
{
  name = "eza",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/eza-community/eza/v%{version}.tar.gz",
      sha256 = "bbf179f2611c904014431740b559e8055276c12fcf978a7e31c271663548337f",
      extract = true,
      strip_prefix = "eza-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    eza = { glob = "usr/bin/eza" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "EUPL-1.2",
      source_provenance = {
        category = 'GithubRepo,
        owner = "eza-community",
        repo = "eza",
      },
    } | Attrs,
} | BuildSpec
