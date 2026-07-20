let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.14.5" in
{
  name = "bottom",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/ClementTsang/bottom/%{version}.tar.gz",
      sha256 = "fab3c85606973e3011241a420b012fc39525c6a5211fe1ad0b564b02b3ef165c",
      extract = true,
      strip_prefix = "bottom-%{version}",
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
    btm = { glob = "usr/bin/btm" } | OutputLib,
    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "bottom",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ClementTsang",
        repo = "bottom",
      },
    } | Attrs,
} | BuildSpec
