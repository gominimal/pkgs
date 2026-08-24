# Auto-bootstrapped from https://github.com/ocaml-ppx/ppx_derivers by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "1.2.1" in
{
  name = "ppx_derivers",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml-ppx/ppx_derivers/archive/refs/tags/%{version}.tar.gz",
      sha256 = "b6595ee187dea792b31fc54a0e1524ab1e48bc6068d3066c45215a138cc73b95",
      extract = true,
      strip_prefix = "ppx_derivers-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    ppx_derivers = { glob = "usr/lib/ocaml/ppx_derivers/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ocaml-ppx", repo = "ppx_derivers" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query ppx_derivers | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
