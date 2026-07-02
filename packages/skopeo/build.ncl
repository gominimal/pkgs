let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let go = import "../go/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.23.0" in
{
  name = "skopeo",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/containers/skopeo/v%{version}.tar.gz",
      sha256 = "de96bfc2bb523c852af675ffdadd934484812ce190aa8620e1d5fd6c51442e25",
      extract = true,
      strip_prefix = "skopeo-%{version}",
    } | Source,
    base,
    go,
    make,
    pkgconf,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    skopeo = { glob = "usr/bin/skopeo" } | OutputBin,

    completions = { glob = "usr/share/bash-completion/completions/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "containers",
        repo = "skopeo",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
