let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "0.29.0" in
{
  name = "tuicr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/agavra/tuicr/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "8e3d06161750b5d98ae6633de9cc47c0720fa86b6aa7afa7652b8aa3c6e85f7a",
      extract = true,
      strip_prefix = "tuicr-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
    zlib, # usr/bin/tuicr NEEDs libz.so.1; it came only through subsetOf gcc (inbox#1261)
  ],

  needs = {
    dns = {},
    internet = {},
  },

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    tuicr = { glob = "usr/bin/tuicr" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "agavra",
        repo = "tuicr",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "tuicr --version"],
          ["/bin/bash", "-c", "tuicr --help"],
        ],
      } | Test,
  },
} | BuildSpec
