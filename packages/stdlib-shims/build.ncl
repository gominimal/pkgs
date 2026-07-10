# Auto-bootstrapped from https://github.com/ocaml/stdlib-shims by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "0.3.0" in
{
  name = "stdlib-shims",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml/stdlib-shims/archive/refs/tags/%{version}.tar.gz",
      sha256 = "6d0386313a021146300011549180fcd4e94f7ac3c3bf021ff165f6558608f0c2",
      extract = true,
      strip_prefix = "stdlib-shims-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    stdlib-shims = { glob = "usr/lib/ocaml/stdlib-shims/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ocaml", repo = "stdlib-shims" },
      license_spdx = "LGPL-2.1-only WITH OCaml-LGPL-linking-exception",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query stdlib-shims | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
