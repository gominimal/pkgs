# Auto-bootstrapped from https://github.com/ocaml-ppx/ppx_deriving_yojson by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let yojson = import "../yojson/build.ncl" in
let ppx_deriving = import "../ppx_deriving/build.ncl" in
let ppxlib = import "../ppxlib/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "3.10.0" in
{
  name = "ppx_deriving_yojson",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml-ppx/ppx_deriving_yojson/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "669a06f573024b5517abb1a89f0cc6eea4a217cb4f17de6cfe618001cbe7df20",
      extract = true,
      strip_prefix = "ppx_deriving_yojson-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    yojson,
    ppx_deriving,
    ppxlib,
    toolchain,
  ],
  cmd = "./build.sh",
  # Discovery default: the single findlib dir. `--from-build` refines this
  # for a multi-package dune project or a `usr/bin/*` CLI.
  outputs = {
    ppx_deriving_yojson = { glob = "usr/lib/ocaml/ppx_deriving_yojson/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, yojson, ppx_deriving, ppxlib],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ocaml-ppx", repo = "ppx_deriving_yojson" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query ppx_deriving_yojson | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
