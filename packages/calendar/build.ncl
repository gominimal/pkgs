# ocaml-community/calendar — date/time library (github release, gs://-mirrored). Needs re + stdlib unix; dep of easy_logging → charon-ml.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let re = import "../re/build.ncl" in
let version = "3.0.0" in
{
  name = "calendar",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/calendar-%{version}.tar.gz",
      sha256 = "ea04d31762d3f18837af0311cdbfe7b7788aa0f2e7e9f98d2b0decec1e506e9e",
      extract = true,
      strip_prefix = "calendar-3.0.0",
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    re,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    calendar = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, re],
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
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query calendar | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
