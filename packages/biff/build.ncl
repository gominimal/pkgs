let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.2.0" in
{
  name = "biff",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/BurntSushi/biff/%{version}.tar.gz",
      sha256 = "5399df79e15ba48e94526319ec6baf4e4e9bbe983693adc4ba784294f0875e78",
      extract = true,
      strip_prefix = "bttf-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
  ],

  cmd = "./build.sh",

  outputs = {
    biff = { glob = "usr/bin/biff" } | OutputBin,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Unlicense",
      source_provenance = {
        category = 'GithubRepo,
        owner = "BurntSushi",
        repo = "bttf",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              v=$(/usr/bin/biff --version 2>&1 || true); [[ $v == bttf\ * ]]
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
