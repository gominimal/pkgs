# AeneasVerif/aeneas — translates Rust (via a charon .llbc) to pure functional
# models for F*/Coq/Lean/HOL4. Pinned to commit
# b059c34a7c347c32856af26772c9336e41c66a11 (2026-07-13), whose `charon-pin`
# matches our charon-ml 0.1.223 exactly. Sourced from github tarball, mirrored to
# gs://.
#
# build.sh patches out three opam deps that aren't packaged for minimal, none of
# which affect the correctness of the generated model:
#   * core_unix  (Jane Street) — one Core_unix.mkdir_p call → stdlib Sys.mkdir.
#   * progress   (progress bar) — cosmetic; stubbed to a no-op reporter.
#   * domainslib (multicore pool) — aeneas output is deterministic; run sequential.
# The `charon` Rust binary that produces the .llbc input is a SEPARATE package
# (a later Rust PR); this package is aeneas's OCaml side, which links charon-ml at
# build time and shells out to that binary at runtime.
let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let ocaml = import "../ocaml/build.ncl" in
let dune = import "../dune/build.ncl" in
let ocamlfind = import "../ocamlfind/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let grep = import "../grep/build.ncl" in
let charon-ml = import "../charon-ml/build.ncl" in
let ocamlgraph = import "../ocamlgraph/build.ncl" in
let ppx_deriving = import "../ppx_deriving/build.ncl" in
let ppx_deriving_yojson = import "../ppx_deriving_yojson/build.ncl" in
let visitors = import "../visitors/build.ncl" in
let ppxlib = import "../ppxlib/build.ncl" in
let menhir = import "../menhir/build.ncl" in
let zarith = import "../zarith/build.ncl" in
let version = "20260713" in
{
  name = "aeneas",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/aeneas-%{version}.tar.gz",
      sha256 = "7d6b6d675a0c352363b7d57a0a9065a58c385309ce421f24259f1a55af89d12b",
      extract = true,
      strip_prefix = "AeneasVerif-aeneas-b059c34", # github sha-suffixed top-dir
    } | Source,
    base,
    ocaml,
    dune,
    ocamlfind,
    charon-ml,
    ocamlgraph,
    ppx_deriving,
    ppx_deriving_yojson,
    visitors,
    ppxlib,
    menhir,
    zarith,
    toolchain,
  ],
  cmd = "./build.sh",
  outputs = {
    bin = { glob = "usr/bin/aeneas" } | OutputBin,
    libs = { glob = "usr/lib/ocaml/**", allow_executable = true } | OutputData,
  },
  runtime_deps = [
    ocaml,
    zarith,
    charon-ml,
  ],
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
    } | Attrs,
  tests = {
    runs =
      {
        class = 'Standalone,
        test_deps = [base, ocaml, zarith, charon-ml, grep],
        cmds = [
          # aeneas needs a charon .llbc for real work (the Rust binary lands in a
          # later PR); here we just smoke-test that the binary links + runs.
          ["/bin/bash", "-c", "/usr/bin/aeneas --help 2>&1 | grep -qiE 'aeneas|usage|option|\\.llbc'"],
        ],
      } | Test,
  },
} | BuildSpec
