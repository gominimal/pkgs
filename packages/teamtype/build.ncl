let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.2" in
{
  name = "teamtype",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/teamtype/teamtype/v%{version}.tar.gz",
      sha256 = "cbf36fd071512e39101aa7de111cbb8b1ae4c0aebf9bd3508eb33e68712bca0f",
      extract = true,
      strip_prefix = "teamtype-%{version}",
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
    teamtype = { glob = "usr/bin/teamtype" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "AGPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "teamtype",
        repo = "teamtype",
      },
    } | Attrs,

  tests.smoketest = standaloneTest "/usr/bin/teamtype --version",
} | BuildSpec
