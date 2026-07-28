let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "0.17.0" in
{
  name = "sexplib0",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Jane Street releases via opam, not GitHub release assets; the archive is
      # the available artifact — pinned by sha256 + mirrored to gs://.
      # https://github.com/janestreet/sexplib0/archive/refs/tags/v0.17.0.tar.gz
      url = "gs://minimal-staging-archives/sexplib0-%{version}.tar.gz",
      sha256 = "5b0910b5dab8ec63633be5dbf92a3e4863d415d803cad9dddf99dba43ce7498b",
      extract = true,
      strip_prefix = "sexplib0-%{version}",
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

  outputs = {
    lib = { glob = "usr/lib/ocaml/sexplib0/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "janestreet",
        repo = "sexplib0",
      },
      build_cost_multiple = 1,
    } | Attrs,

  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, dune, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'let () = print_string (Sexplib0.Sexp.to_string (Sexplib0.Sexp.Atom \"ok\"))' > t.ml && OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind ocamlopt -package sexplib0 -linkpkg t.ml -o t && ./t | grep -q ok"],
        ],
      } | Test,
  },
} | BuildSpec
