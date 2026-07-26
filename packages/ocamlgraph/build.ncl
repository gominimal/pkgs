# Auto-bootstrapped from https://github.com/backtracking/ocamlgraph by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "2.2.0" in
{
  name = "ocamlgraph",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/backtracking/ocamlgraph/archive/refs/tags/%{version}.tar.gz",
      sha256 = "0c183118bc62fb0851fac5e195293067cf8863edd2dabf322d20583d65bb7758",
      extract = true,
      strip_prefix = "ocamlgraph-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    toolchain,
  ],
  cmd = "./build.sh",
  # Discovery default: the single findlib dir. `--from-build` refines this
  # for a multi-package dune project or a `usr/bin/*` CLI.
  outputs = {
    ocamlgraph = { glob = "usr/lib/ocaml/ocamlgraph/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "backtracking", repo = "ocamlgraph" },
      license_spdx = "LGPL-2.1-only WITH OCaml-LGPL-linking-exception",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query ocamlgraph | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
