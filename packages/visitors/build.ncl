# fpottier/visitors — ppx generating visitor classes; from gitlab.inria.fr,
# mirrored to gs:// (no `Gitlab` provenance category yet, minimal-supply-chain#347).
# Needed by charon-ml and aeneas. 20251114 matches our ppxlib 0.38.0 (opam wants
# ppxlib >= 0.37.0, ppx_deriving >= 5.0) and stays clear of OCaml 5.4+ APIs.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let result = import "../result/build.ncl" in
let ppxlib = import "../ppxlib/build.ncl" in
let ppx_deriving = import "../ppx_deriving/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "20251114" in
{
  name = "visitors",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/visitors-%{version}.tar.gz",
      sha256 = "1d84a624fa5a162e381af659c6cfd64a15c2abeeb32f5925ed5870c53de262b6",
      extract = true,
      strip_prefix = "visitors-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    ppxlib,
    result,
    ppx_deriving,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    visitors = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, ppx_deriving, result],
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.0-only",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query visitors | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
