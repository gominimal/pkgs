let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "1.5.2" in
{
  name = "csexp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml-dune/csexp/releases/download/1.5.2/csexp-1.5.2.tbz
      url = "gs://minimal-staging-archives/csexp-%{version}.tbz",
      sha256 = "1a14dd04bb4379a41990248550628c77913a9c07f3c35c1370b6960e697787ff",
      extract = false,
    } | Source,
    base,
    ocaml,
    dune,
    toolchain,
  ],
  runtime_deps = [
    ocaml,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    lib = { glob = "usr/lib/ocaml/csexp/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ocaml-dune",
        repo = "csexp",
      },
      build_cost_multiple = 1,
    } | Attrs,

  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, dune, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'let () = print_string (Csexp.to_string (Csexp.Atom \"ok\"))' > t.ml && OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind ocamlopt -package csexp -linkpkg t.ml -o t && ./t | grep -q ok"],
        ],
      } | Test,
  },
} | BuildSpec
