let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let seq = import "../seq/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "3.0.0" in
{
  name = "yojson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml-community/yojson/releases/download/3.0.0/yojson-3.0.0.tbz
      url = "gs://minimal-staging-archives/yojson-%{version}.tbz",
      sha256 = "99414da7609b92a02474ef4b49ecda15edc8cbba5229341b124e7e4695c39610",
      extract = false,
    } | Source,
    base,
    ocaml,
    dune,
    seq,
    toolchain,
  ],
  # A pure-OCaml library: bytecode users need ocamlrun from `ocaml`; `seq` is an
  # empty findlib shim yojson's META `requires` (Seq itself is stdlib on OCaml 5).
  runtime_deps = [
    ocaml,
    seq,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    # ydump, the pretty-printer CLI that ships with the package.
    bin = { glob = "usr/bin/ydump" } | OutputBin,
    # The findlib library tree (META + *.cma/.cmxa/.cmi/.a) under OCAMLPATH.
    lib = { glob = "usr/lib/ocaml/yojson/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ocaml-community",
        repo = "yojson",
      },
      build_cost_multiple = 1,
    } | Attrs,

  tests = {
    # The linchpin: compile + run a program that USES yojson, resolved via
    # findlib from OCAMLPATH — proves the whole offline dune-lib model end to
    # end (dep installed to the merged /usr tree, found with no network).
    findlib_resolve_and_run =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, dune, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'let () = print_string (Yojson.Safe.to_string (`Int 42))' > t.ml && OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind ocamlopt -package yojson -linkpkg t.ml -o t && ./t | grep -q 42"],
        ],
      } | Test,
  },
} | BuildSpec
