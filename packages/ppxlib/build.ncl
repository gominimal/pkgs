# Auto-bootstrapped from https://github.com/ocaml-ppx/ppxlib by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocaml-compiler-libs = import "../ocaml-compiler-libs/build.ncl" in
let ppx_derivers = import "../ppx_derivers/build.ncl" in
let sexplib0 = import "../sexplib0/build.ncl" in
let stdlib-shims = import "../stdlib-shims/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "0.38.0" in
{
  name = "ppxlib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml-ppx/ppxlib/archive/refs/tags/%{version}.tar.gz",
      sha256 = "cb88f34179731182aa73bb25e4d081f94a6a9a7f99b1f818ddb2969f97123b19",
      extract = true,
      strip_prefix = "ppxlib-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    ocaml-compiler-libs,
    ppx_derivers,
    sexplib0,
    stdlib-shims,
    toolchain,
  ],
  cmd = "./build.sh",
  # Discovery default: the single findlib dir. `--from-build` refines this
  # for a multi-package dune project or a `usr/bin/*` CLI.
  outputs = {
    ppxlib = { glob = "usr/lib/ocaml/ppxlib/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, ocaml-compiler-libs, ppx_derivers, sexplib0, stdlib-shims],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ocaml-ppx", repo = "ppxlib" },
      license_spdx = "MIT",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query ppxlib | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
