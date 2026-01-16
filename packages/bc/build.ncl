let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let readline = import "../readline/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "7.0.3" in
{
  name = "bc",
  inputs = [
    {
      url = "gs://minimal-staging-archives/bc-%{version}.tar.xz",
      sha256 = "91eb74caed0ee6655b669711a4f350c25579778694df248e28363318e03c7fc4"
    } | Source,
    { file = "build.sh" } | Local,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "bc-gh",
    } | Attrs,

  tests = {
    arithmetic =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo '2 + 2' | bc > bc_result.txt"],
          ["/bin/bash", "-c", "grep -q '^4$' bc_result.txt"],
        ],
      } | Test,
    fp_and_scale =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "echo 'scale=2; 10 / 3' | bc > bc_float.txt"],
          ["/bin/bash", "-c", "grep -q '^3.33$' bc_float.txt"],
        ],
      } | Test,
    multiline =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "bc > bc_multi.txt << EOF\nx = 5\ny = 7\nx * y\nEOF"],
          ["/bin/bash", "-c", "grep -q '^35$' bc_multi.txt"],
        ],
      } | Test,
  },
} | BuildSpec
