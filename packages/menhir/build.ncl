# fpottier/menhir — LR(1) parser generator; from gitlab.inria.fr, mirrored to
# gs:// (no `Gitlab` provenance category yet — minimal-supply-chain#347). Needed
# to build charon-ml's name_matcher_parser (menhir binary generates the parser;
# menhirLib is linked at runtime). 20240715 predates OCaml 5.4 APIs, self-contained.
#
# Dual license: THE GENERATOR (the `menhir` binary) is GPL-2.0-only; THE RUNTIME
# LIBRARY + SDK (menhirLib / menhirCST / menhirSdk) are LGPL-2.0-only WITH a
# library linking exception — so a parser generated + linked against menhirLib is
# NOT itself forced to GPL. The binary is build-time-only here.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "20240715" in
{
  name = "menhir",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/menhir-%{version}.tar.gz",
      sha256 = "dca7b86e81b5dbe24f52c451be00bdbdfede3d9e81317ebe5220aaa3ee33ee42",
      extract = true,
      strip_prefix = "menhir-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    bin = { glob = "usr/bin/menhir" } | OutputBin,
    libs = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only AND LGPL-2.0-only",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query menhirLib | grep -q /usr/lib/ocaml"],
          ["/bin/bash", "-c", "/usr/bin/menhir --version | grep -qi menhir"],
        ],
      } | Test,
  },
} | BuildSpec
