# ocaml/ocaml-re — pure-OCaml regex library (github release, gs://-mirrored). Dep of calendar → easy_logging → charon-ml on the OCaml→aeneas spine.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let seq = import "../seq/build.ncl" in
let version = "1.12.0" in
{
  name = "re",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/re-%{version}.tar.gz",
      sha256 = "b300e58638123ab948d2606bf5de41d5b7ac69c2ad0ca642cef2801c1563fa66",
      extract = true,
      strip_prefix = "ocaml-re-1.12.0",
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    seq,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    re = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, seq],
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.1-or-later WITH OCaml-LGPL-linking-exception",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query re | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
