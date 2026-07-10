let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "0.3.1" in
{
  name = "seq",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/c-cube/seq/archive/refs/tags/v0.3.1.tar.gz
      url = "gs://minimal-staging-archives/seq-%{version}.tar.gz",
      sha256 = "6bc8beb15f0a678dbd6f8b4f75a2cc45fa2d9e4cf545eafe9fb057c97c9914cf",
      extract = true,
      strip_prefix = "seq-%{version}",
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
    # On OCaml >= 4.07 `Seq` is in the stdlib, so this findlib package is an
    # empty compatibility shim (just a META) — its only job is to let
    # downstreams' `(libraries seq)` resolve. Same as opam's `seq` on OCaml 5.
    lib = { glob = "usr/lib/ocaml/seq/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "c-cube",
        repo = "seq",
      },
      build_cost_multiple = 1,
    } | Attrs,

  tests = {
    # Prove `-package seq` resolves via findlib AND that Seq works (from stdlib
    # on OCaml 5) — the offline-resolve proof for the shim.
    findlib_resolve_and_run =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, dune, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'let () = Seq.iter print_int (List.to_seq [1;2;3])' > t.ml && OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind ocamlopt -package seq -linkpkg t.ml -o t && ./t | grep -q 123"],
        ],
      } | Test,
  },
} | BuildSpec
