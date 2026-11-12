let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# The latest upstream release, deliberately NOT the one Lean bundles (lean4
# 4.35's CMakeLists.txt pins rel-2.1.2): we run current versions and fix what
# breaks. A newer solver cannot make Lean accept a false goal, because
# `bv_decide` checks the solver's LRAT certificate in Lean's own verified
# checker. A solver change can only make a proof fail: a rejected
# certificate, a timeout, or a changed message. Two places would show that:
#   - lean's `bv_decide` standalone test is a smoke test. It checks that
#     cadical is found and that lean accepts the certificates it writes for
#     four goals. Three goals are small and one is Aeneas's ML-KEM
#     conditional-subtraction goal, restated on plain `BitVec 32`. It also
#     checks that a false goal is refuted with a counterexample.
#   - aeneas-latest's library build covers real goals. `lake build Aeneas`
#     runs 60 solver call sites: 9 `bv_decide` (Bvify) and 51 `bv_tac`, which
#     ends in `bv_decide` (BvTac's examples, its Tests and 30 simp lemmas).
#     The goals are 8- to 128-bit scalar goals. Any failure fails that build,
#     and a cadical change re-keys it, so the build-bot rebuilds it.
let version = "3.0.1" in
{
  name = "cadical",
  # CaDiCaL, the SAT solver behind Lean's `bv_decide`. Official Lean releases
  # ship it next to `lean`; a from-source lean build does not, and `bv_decide`
  # then fails with "could not execute external process 'cadical'". It is found
  # by name on PATH, so this package is enough.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/arminbiere/cadical/archive/refs/tags/rel-%{version}.tar.gz",
      sha256 = "0a8ea563b5a25f5aa064634814edab45cc0e45111ea0f5d412a565f806fd7e11",
      extract = true,
      strip_prefix = "cadical-rel-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cadical = { glob = "usr/bin/cadical" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "arminbiere",
        repo = "cadical",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "cadical --version"],
          # A two-clause satisfiable formula: exit code 10 is SAT by DIMACS convention.
          ["/bin/bash", "-c", "printf 'p cnf 2 2\\n1 2 0\\n-1 0\\n' > /tmp/f.cnf; cadical -q /tmp/f.cnf; test $? -eq 10"],
        ],
      } | Test,
  },
} | BuildSpec
