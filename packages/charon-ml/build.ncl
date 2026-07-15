# AeneasVerif/charon — the OCaml bindings (charon-ml/), pinned to charon 0.1.223
# (commit 5a5017333554ec1e95cae3c4fe05f5bd90b44487, 2026-07-11). Builds the
# `charon` findlib lib (LLBC/ULLBC deserialization) + `name_matcher_parser`
# (ocamllex+menhir grammar). This is the OCaml half only — the `charon` Rust
# binary that emits .llbc is a separate package (a later Rust PR); aeneas links
# THIS lib at build time and invokes that binary at runtime.
#
# Sourced from github tarball, mirrored to gs://. GitLab-hosted transitive deps
# (unionFind/visitors/menhir) ride gs:// too — no `Gitlab` provenance category
# yet (minimal-supply-chain#347).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let yojson = import "../yojson/build.ncl" in
let zarith = import "../zarith/build.ncl" in
let easy_logging = import "../easy_logging/build.ncl" in
let unionfind = import "../unionfind/build.ncl" in
let visitors = import "../visitors/build.ncl" in
let menhir = import "../menhir/build.ncl" in
let ppx_deriving = import "../ppx_deriving/build.ncl" in
let ppxlib = import "../ppxlib/build.ncl" in
let version = "0.1.223" in
{
  name = "charon-ml",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/charon-ml-%{version}.tar.gz",
      sha256 = "a7953f71f598725eefb33671301a99ae5f683055184a6038f8a0da9fbb8b7d9a",
      extract = true,
      strip_prefix = "AeneasVerif-charon-5a50173", # github sha-suffixed top-dir
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    yojson,
    zarith,
    easy_logging,
    unionfind,
    visitors,
    menhir,
    ppx_deriving,
    ppxlib,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    charon-ml = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [
    ocaml,
    yojson,
    zarith,
    easy_logging,
    unionfind,
    visitors,
    menhir,
    ppx_deriving,
  ],
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query charon | grep -q /usr/lib/ocaml"],
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query name_matcher_parser | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
