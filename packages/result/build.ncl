# janestreet/result — the `Result` compat findlib shim (github release,
# mirrored to gs://). A build+runtime dep of visitors.runtime; `Result` itself
# is stdlib on OCaml 5, but the findlib package must still resolve.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "1.5" in
{
  name = "result",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://github.com/janestreet/result release 1.5
      url = "gs://minimal-staging-archives/result-%{version}.tar.gz",
      sha256 = "1072a8b0b35bd6df939c0670add33027f981e4f69a53233cb006b442fa12af30",
      extract = true,
      strip_prefix = "result-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    result = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query result | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
