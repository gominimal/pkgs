let { standaloneTest, subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.2.0" in
{
  name = "jaq",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/01mf02/jaq/v%{version}.tar.gz",
      sha256 = "5478dd880f98abe4fdf13e7c38289aaa98b25e063ba40e8b9e69b22e2dc64ce7",
      extract = true,
      strip_prefix = "jaq-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",

  outputs = {
    jaq = { glob = "usr/bin/jaq" } | OutputBin,
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
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "echo '[{\"name\":\"x\",\"val\":10},{\"name\":\"y\",\"val\":20},{\"name\":\"z\",\"val\":5}]' > items.json"],
          ["/bin/bash", "-c", "jaq '[.[] | select(.val > 10)]' items.json > filtered.json"],
          ["/bin/bash", "-c", "jaq 'length' filtered.json | grep -q '^1$'"],
        ],
      } | Test,
  },
} | BuildSpec
