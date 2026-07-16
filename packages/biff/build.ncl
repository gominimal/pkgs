let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.1.4" in
{
  name = "biff",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/BurntSushi/biff/%{version}.tar.gz",
      sha256 = "21b265959403c02406137adac1012f676a25ad67d6fbf29a553b9e459c7bbc73",
      extract = true,
      strip_prefix = "biff-%{version}",
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
    biff = { glob = "usr/bin/biff" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Unlicense",
      source_provenance = {
        category = 'GithubRepo,
        owner = "BurntSushi",
        repo = "biff",
      },
    } | Attrs,
} | BuildSpec
