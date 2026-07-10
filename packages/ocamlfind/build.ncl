let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "1.9.8" in
{
  name = "ocamlfind",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml/ocamlfind/archive/refs/tags/findlib-1.9.8.tar.gz
      url = "https://github.com/ocaml/ocamlfind/archive/refs/tags/findlib-%{version}.tar.gz",
      sha256 = "d6899935ccabf67f067a9af3f3f88d94e310075d13c648fa03ff498769ce039d",
      extract = true,
      strip_prefix = "ocamlfind-findlib-%{version}",
    } | Source,
    base,
    ocaml,
    make,
    toolchain,
  ],
  runtime_deps = [
    ocaml,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
    conf = { glob = "usr/lib/findlib.conf" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ocaml",
        repo = "ocamlfind",
      },
      build_cost_multiple = 1,
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [base, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/ocamlfind list 2>&1 | grep -qi findlib"],
        ],
      } | Test,
  },
} | BuildSpec
