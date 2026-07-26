let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.1.0" in
{
  name = "jaq",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/01mf02/jaq/v%{version}.tar.gz",
      sha256 = "8ad074d7e90e07ad7e77048dcf0d0e7ad434b8e3e38044260b9457d4551e644d",
      extract = true,
      strip_prefix = "jaq-%{version}",
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
    jaq = { glob = "usr/bin/jaq" } | OutputLib,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "01mf02",
        repo = "jaq",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/jaq --version",

    filtering =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '[{\"name\":\"x\",\"val\":10},{\"name\":\"y\",\"val\":20},{\"name\":\"z\",\"val\":5}]' > items.json"],
          ["/bin/bash", "-c", "jaq '[.[] | select(.val > 10)]' items.json > filtered.json"],
          ["/bin/bash", "-c", "jaq 'length' filtered.json | grep -q '^1$'"],
        ],
      } | Test,
  },
} | BuildSpec
