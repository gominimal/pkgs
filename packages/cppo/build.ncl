# Auto-bootstrapped from https://github.com/ocaml-community/cppo by `pkgmgr bootstrap` (ocaml/dune build).
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "1.6.9" in
{
  name = "cppo",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml-community/cppo/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "16036d85c11d330a7c8b56f4e071d6bbe86d8937c89d3d79f6eef0e38bdda26a",
      extract = true,
      strip_prefix = "cppo-%{version}",
    } | Source,
    base,
    ocaml,
    dune,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    bin = { glob = "usr/bin/cppo" } | OutputBin,
    cppo = { glob = "usr/lib/ocaml/cppo/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "ocaml-community", repo = "cppo" },
      license_spdx = "BSD-3-Clause",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query cppo | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
