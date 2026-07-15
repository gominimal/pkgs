# Auto-bootstrapped from https://github.com/janestreet/ocaml-compiler-libs by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "0.17.0" in
{
  name = "ocaml-compiler-libs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/janestreet/ocaml-compiler-libs/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "9b9644d7351db699e57ddba7c767bb4153e6e988ccf45ead2fb238a3bd75cdc7",
      extract = true,
      strip_prefix = "ocaml-compiler-libs-%{version}",
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
    ocaml-compiler-libs = { glob = "usr/lib/ocaml/ocaml-compiler-libs/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "janestreet", repo = "ocaml-compiler-libs" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query ocaml-compiler-libs | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
