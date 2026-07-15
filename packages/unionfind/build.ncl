# fpottier/unionFind — from gitlab.inria.fr, mirrored to gs:// (no `Gitlab`
# source_provenance category yet — see minimal-supply-chain#347). Offline dune
# lib; a hard dep of charon-ml on the OCaml→aeneas spine.
#
# Pinned to the 20220122 release: it is self-contained (ocaml+dune only, stable
# make/union/find API charon-ml consumes). The latest 20260226 pulls in a `store`
# backend and a multicore `Atomic.Loc.compare_and_set` that needs OCaml 5.4+ —
# our ocaml is 5.3.0, so the newest release FTBFS here (Unbound module Atomic.Loc).
let { Attrs, BuildSpec, Local, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let version = "20220122" in
{
  name = "unionfind",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/unionFind-%{version}.tar.gz",
      sha256 = "f39fb928d60a5ec3401f9ebca91f3f0050bd503be22c910efc5ced73d7111d90",
      extract = true,
      strip_prefix = "unionfind-20220122-77e9aa955eab31718cc912ea212d32ff087f16ed", # gitlab sha-suffixed top-dir (minimal-supply-chain#347),
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    unionFind = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [ocaml],
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.0-only",
    } | Attrs,
  tests = {
    findlib_resolve =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, ocamlfind, toolchain, grep, coreutils],
        cmds = [
          ["/bin/bash", "-c", "OCAMLPATH=/usr/lib/ocaml /usr/bin/ocamlfind query unionFind | grep -q /usr/lib/ocaml"],
        ],
      } | Test,
  },
} | BuildSpec
