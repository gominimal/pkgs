let { standaloneTest, subsetOf, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.5.14" in
{
  name = "biome",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/biomejs/biome/archive/refs/tags/@biomejs/biome@%{version}.tar.gz",
      sha256 = "5b87b7df94e8c6b968d44daecf92c46231908012be5f6f41ac33bcabbd53e66e",
      extract = true,
      strip_prefix = "biome--biomejs-biome-%{version}",
    } | Source,
    base,
    make,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    bins = { glob = "usr/bin/biome" } | OutputBin,
  },

  needs = {
    internet = {},
  },

  attrs = {
    upstream_version = version,
    license_spdx = "MIT OR Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "biomejs",
      repo = "biome",
    },
  },

  tests = {
    smoketest = standaloneTest "/usr/bin/biome --version",

    # Regression test for gominimal/pkgs#637. biome_cli's Cargo version is
    # literally "0.0.0" — upstream stamps the real one through BIOME_VERSION at
    # compile time — so an unstamped build reports 0.0.0 and biome then warns
    # that every `$schema` in a config "does not match the CLI version". Assert
    # the exact string: a substring match would still pass on "0.0.0".
    version_is_stamped =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "test \"$(/usr/bin/biome --version)\" = 'Version: %{version}'"],
        ],
      } | Test,
  },
} | BuildSpec
