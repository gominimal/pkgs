# sapristi/easy_logging — logging library (github tarball, gs://-mirrored). Uses calendar for timestamps; a hard dep of charon-ml on the OCaml→aeneas spine.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let calendar = import "../calendar/build.ncl" in
let version = "0.8.2" in
{
  name = "easy_logging",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/easy_logging-%{version}.tar.gz",
      sha256 = "dd472268f5ae4bdd242ea2e046710b1d06709bff2c13a93960ae3b85cc34c775",
      extract = true,
      strip_prefix = "sapristi-easy_logging-03ec4c6",
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    calendar,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    easy_logging = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, calendar],
  attrs =
    {
      upstream_version = version,
      license_spdx = "MPL-2.0",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query easy_logging | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
