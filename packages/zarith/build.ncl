# Hand-authored: zarith is NON-dune (./configure + make + `ocamlfind install`)
# and links system GMP — the T3 "C-system-lib" path, Phase A's capstone.
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let make = import "../make/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "1.14" in
{
  name = "zarith",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ocaml/Zarith/archive/refs/tags/release-%{version}.tar.gz",
      sha256 = "5db9dcbd939153942a08581fabd846d0f3f2b8c67fe68b855127e0472d4d1859",
      extract = true,
      strip_prefix = "Zarith-release-%{version}",
    } | Source,
    base,
    ocaml,
    ocamlfind,
    make,
    gmp,
    pkgconf,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    zarith = { glob = "usr/lib/ocaml/zarith/**", allow_executable = true } | OutputData,
    stublibs = { glob = "usr/lib/ocaml/stublibs/dllzarith.so", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml, gmp],
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.0-only WITH OCaml-LGPL-linking-exception",
      source_provenance = { category = 'GithubRepo, owner = "ocaml", repo = "Zarith" },
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query zarith | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
