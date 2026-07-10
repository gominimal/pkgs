let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "2.2.2" in
{
  name = "yojson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/ocaml-community/yojson/releases/download/2.2.2/yojson-2.2.2.tbz
      url = "https://github.com/ocaml-community/yojson/releases/download/%{version}/yojson-%{version}.tbz",
      sha256 = "9abfad8c9a79d4723ad2f6448e669c1e68dbfc87cc54a1b7c064b0c90912c595",
      extract = false,
    } | Source,
    base,
    ocaml,
    dune,
    toolchain,
  ],
  # A pure-OCaml library: bytecode users need ocamlrun from `ocaml`; native
  # users link nothing extra. (`seq` is stdlib on OCaml 5, so no dep for it.)
  runtime_deps = [
    ocaml,
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
