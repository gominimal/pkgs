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
      # Mirror of findlib's OFFICIAL camlcity release tarball — NOT the GitHub
      # auto-generated archive, whose contents/checksum can change over time
      # (per dune-release guidance: pin the upstream release artifact).
      # http://download.camlcity.org/download/findlib-1.9.8.tar.gz
      url = "gs://minimal-staging-archives/findlib-%{version}.tar.gz",
      sha256 = "662c910f774e9fee3a19c4e057f380581ab2fc4ee52da4761304ac9c31b8869d",
      extract = true,
      strip_prefix = "findlib-%{version}",
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
    list =
      {
        class = 'Standalone,
        test_deps = [base, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/ocamlfind list 2>&1 | grep -qi findlib"],
        ],
      } | Test,
    # Prove ocamlfind actually resolves + drives the compiler: query a known
    # package for its dir, then compile a program via `ocamlfind ocamlopt`
    # (the path non-dune libraries like zarith rely on).
    query_and_compile =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query stdlib | grep -q /usr/lib/ocaml"],
          ["/bin/bash", "-c", "echo 'let () = print_string \"ok\"' > t.ml && OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind ocamlopt t.ml -o t && ./t | grep -q ok"],
        ],
      } | Test,
  },
} | BuildSpec
