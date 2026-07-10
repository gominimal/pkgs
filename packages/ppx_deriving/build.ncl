# Auto-bootstrapped from https://github.com/ocaml-ppx/ppx_deriving by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let cppo = import "../cppo/build.ncl" in
let ppx_derivers = import "../ppx_derivers/build.ncl" in
let ppxlib = import "../ppxlib/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "6.1.2" in
{
  name = "ppx_deriving",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml-ppx/ppx_deriving/archive/refs/tags/%{version}.tar.gz",
      sha256 = "76d759a112a6cd55d6043911a05a21236a44785bf11792612cf5856ed818387b",
      extract = true,
      strip_prefix = "ppx_deriving-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    cppo,
    ocamlfind,
    ppx_derivers,
    ppxlib,
    toolchain,
  ],
  cmd = "./build.sh",
  # Discovery default: the single findlib dir. `--from-build` refines this
  # for a multi-package dune project or a `usr/bin/*` CLI.
  outputs = {
    ppx_deriving = { glob = "usr/lib/ocaml/ppx_deriving/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, ppxlib, ppx_derivers],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ocaml-ppx", repo = "ppx_deriving" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query ppx_deriving | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
