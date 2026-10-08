let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let py-pyparsing = import "../py-pyparsing/build.ncl" in
let symfpu = import "../symfpu/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

# cvc5, the SMT solver. Latest stable release. Downstream pins, for reference
# when bumping: Verus pins cvc5 1.1.2, Creusot pins 1.3.1 — both older than
# this; cvc5's SMT-LIB front end is what they drive, so the newer release is a
# drop-in for them.
let version = "1.4.2" in

# CaDiCaL: cvc5 pins its OWN CaDiCaL — branch `rel-2.1.3-elevate` of
# arminbiere/cadical, i.e. 2.1.3 plus six upstream fixes to the external
# propagator interface cvc5's SAT solver drives (FindCaDiCaL.cmake). The fleet's
# `cadical` package is 2.1.2 and ships only the `cadical` executable (no
# libcadical.a, no headers), so it can't be linked against. We build the pinned
# library here from source, statically, exactly as cvc5's own ExternalProject
# would, and pin it by COMMIT (the branch head cvc5's checksum matches) rather
# than by branch name, which can move.
let cadical_commit = "a384d221a920d473b770df6a7221f35fc5d99e90" in
{
  name = "cvc5",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/cvc5/cvc5/archive/refs/tags/cvc5-%{version}.tar.gz",
      sha256 = "795099b277bfa79a3c9a11c8d3fec780452031dc89ddcc170003963aa3521343",
      extract = true,
      strip_prefix = "cvc5-cvc5-%{version}",
    } | Source,
    {
      url = "https://github.com/arminbiere/cadical/archive/%{cadical_commit}.tar.gz",
      sha256 = "244f9f7ea2c9b870e94a44b28e903a3f79410201f5e8ac0b4eb2feb57422eeaa",
      extract = false,
    } | Source,
    base,
    toolchain,
    cmake,
    # CaDiCaL's makefile.
    make,
    ninja,
    # Configure-time code generators (options, kinds, rewrite-rule DSL);
    # rw_parser.py needs pyparsing.
    python,
    py-pyparsing,
    # Header-only, compiled in; cvc5's FP theory bit-blasts through it.
    symfpu,
    gmp,
  ],

  runtime_deps = [
    glibc,
    gmp,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include cadical_commit,
  },

  outputs = {
    cvc5 = { glob = "usr/bin/cvc5" } | OutputBin,
    libs = { glob = "usr/lib/libcvc5*.so*" } | OutputLib,
    includes = { glob = "usr/include/cvc5/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/cvc5/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # BSD-3-Clause for cvc5 itself (COPYING); the bundled MiniSat
      # (src/prop/minisat) and the statically linked CaDiCaL are MIT. Every
      # GPL-licensed optional library (CLN, GLPK, CoCoA, Normaliz) is OFF —
      # see build.sh — so the binary is not GPL. GMP is linked dynamically
      # (LGPL-3.0, per COPYING the combined work stays BSD).
      license_spdx = "BSD-3-Clause AND MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cvc5",
        repo = "cvc5",
      },
      build_cost_multiple = 4,
    } | Attrs,

  tests = {
    # Actually solve things, not just --version. Each query has a unique
    # answer, and the second also checks the model.
    solve =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cvc5 --version | head -1 | grep -Fx 'cvc5 %{version}'"],
          # QF_BV sat: 3 is odd, hence invertible mod 2^8, so x*3 = 15 has the
          # single solution x = 5.
          ["/bin/bash", "-c", "printf '(set-logic QF_BV)\\n(set-option :produce-models true)\\n(declare-const x (_ BitVec 8))\\n(assert (= (bvmul x #x03) #x0f))\\n(check-sat)\\n(get-value (x))\\n' > /tmp/sat.smt2 && out=$(cvc5 /tmp/sat.smt2) && echo \"$out\" && test \"$out\" = \"$(printf 'sat\\n((x #b00000101))')\""],
          # QF_BV unsat: nothing is unsigned-less-than zero.
          ["/bin/bash", "-c", "printf '(set-logic QF_BV)\\n(declare-const x (_ BitVec 32))\\n(assert (bvult x #x00000000))\\n(check-sat)\\n' > /tmp/unsat.smt2 && out=$(cvc5 /tmp/unsat.smt2) && echo \"$out\" && test \"$out\" = unsat"],
          # QF_FP unsat (exercises the SymFPU bit-blaster): a + a = 4 forces
          # a = 2 exactly in binary32.
          ["/bin/bash", "-c", "printf '(set-logic QF_FP)\\n(declare-const a Float32)\\n(assert (fp.eq (fp.add RNE a a) ((_ to_fp 8 24) RNE 4.0)))\\n(assert (not (fp.eq a ((_ to_fp 8 24) RNE 2.0))))\\n(check-sat)\\n' > /tmp/fp.smt2 && out=$(cvc5 /tmp/fp.smt2) && echo \"$out\" && test \"$out\" = unsat"],
        ],
      } | Test,
  },
} | BuildSpec
