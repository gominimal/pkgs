let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let py-pyparsing = import "../py-pyparsing/build.ncl" in
let symfpu = import "../symfpu/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let libpoly = import "../libpoly/build.ncl" in
let cocoalib = import "../cocoalib/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

# cvc5 WITH finite fields (QF_FF): the `cvc5` package's build plus CoCoALib,
# whose Groebner bases cvc5's finite-field solver runs on.
#
# This is a separate, opt-in package because CoCoALib is GPL-3.0-or-later:
# linking it makes the whole cvc5 binary GPL-3.0-or-later (cvc5's COPYING,
# "OPTIONAL GPLv3 libraries"; its CMake refuses USE_COCOA without
# ENABLE_GPL). The default `cvc5` stays BSD. Under the FV licence policy
# (pkgmgr-rs#1181) this is tier C, an isolated GPL executable, so the package
# is shaped to stay one:
#  - the program is installed as `cvc5-ff`, not `cvc5`. It can't shadow the
#    BSD cvc5 in an environment that has both, and choosing GPL is explicit
#    (a tool that runs `cvc5` needs to be pointed at `cvc5-ff`);
#  - libcvc5 / libcvc5parser (now GPL) live in a private usr/lib/cvc5-ff,
#    found through the binary's $ORIGIN RUNPATH; no headers and no CMake
#    package config are shipped, so nothing else can build against them.
#
# Keep `version` and `cadical_commit` in step with packages/cvc5: same
# release, same pinned CaDiCaL (see the comments there).
let version = "1.4.2" in
let cadical_commit = "a384d221a920d473b770df6a7221f35fc5d99e90" in
{
  name = "cvc5-ff",

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
    # Configure-time code generators; rw_parser.py needs pyparsing.
    python,
    py-pyparsing,
    symfpu,
    gmp,
    libpoly,
    # Static (libcocoa.a, carrying cvc5's own patch), linked into libcvc5.
    cocoalib,
  ],

  runtime_deps = [
    glibc,
    gmp,
    subsetOf libpoly ["libs"],
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include cadical_commit,
  },

  outputs = {
    cvc5-ff = { glob = "usr/bin/cvc5-ff" } | OutputBin,
    libs = { glob = "usr/lib/cvc5-ff/libcvc5*.so*" } | OutputLib,
  },

  attrs =
    {
      upstream_version = version,
      # cvc5 is BSD-3-Clause and its bundled MiniSat and the static CaDiCaL
      # MIT, but CoCoALib (GPL-3.0-or-later, statically linked) makes the
      # combined work GPL-3.0-or-later; `cvc5-ff --copyright` says so. GMP
      # and LibPoly stay LGPL-3.0-or-later shared libraries (their own
      # packages).
      license_spdx = "GPL-3.0-or-later AND BSD-3-Clause AND MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "cvc5",
        repo = "cvc5",
      },
      build_cost_multiple = 4,
    } | Attrs,

  tests = {
    solve =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "cvc5-ff --version | head -1 | grep -Fx 'cvc5 %{version}'"],
          # Only the renamed program: no `cvc5` to shadow the BSD package.
          ["/bin/bash", "-c", "! command -v cvc5"],
          # The configuration is what we meant: CoCoA and LibPoly in, and
          # cvc5 itself reports the GPL terms.
          ["/bin/bash", "-c", "c=$(cvc5-ff --show-config) && echo \"$c\" && echo \"$c\" | grep -Ex 'cocoa +: yes' && echo \"$c\" | grep -Ex 'poly +: yes'"],
          ["/bin/bash", "-c", "cvc5-ff --copyright | grep -Fx 'This build of cvc5 uses GPLed libraries, and is thus covered by'"],
          # QF_FF sat: in GF(7), x^2 = 2 has the roots 3 and 4; excluding 3
          # leaves exactly x = 4, which the model must report.
          ["/bin/bash", "-c", "printf '(set-logic QF_FF)\\n(set-option :produce-models true)\\n(define-sort F () (_ FiniteField 7))\\n(declare-const x F)\\n(assert (= (ff.mul x x) #f2m7))\\n(assert (not (= x #f3m7)))\\n(check-sat)\\n(get-value (x))\\n' > /tmp/ffsat.smt2 && out=$(cvc5-ff /tmp/ffsat.smt2) && echo \"$out\" && test \"$(echo \"$out\" | head -1)\" = sat && echo \"$out\" | tail -1 | grep -Ex '\\(\\(x #f(4|-3)m7\\)\\)'"],
          # QF_FF unsat: 3 is a quadratic non-residue mod 7 (the squares are
          # 0, 1, 2, 4), so x^2 = 3 has no solution. Needs the Groebner-basis
          # solver; without CoCoA cvc5 rejects the logic outright.
          ["/bin/bash", "-c", "printf '(set-logic QF_FF)\\n(define-sort F () (_ FiniteField 7))\\n(declare-const x F)\\n(assert (= (ff.mul x x) #f3m7))\\n(check-sat)\\n' > /tmp/ffunsat.smt2 && out=$(cvc5-ff /tmp/ffunsat.smt2) && echo \"$out\" && test \"$out\" = unsat"],
          # A 254-bit prime field (BN254's scalar field, the zk-circuit use
          # case) parses and decides: b*(b-1) = 0 (b is a bit) with b = 2.
          ["/bin/bash", "-c", "p=21888242871839275222246405745257275088548364400416034343698204186575808495617; printf \"(set-logic QF_FF)\\n(define-sort F () (_ FiniteField $p))\\n(declare-const b F)\\n(assert (= (ff.mul b (ff.add b (ff.neg #f1m$p))) #f0m$p))\\n(assert (= b #f2m$p))\\n(check-sat)\\n\" > /tmp/ffbig.smt2 && out=$(cvc5-ff /tmp/ffbig.smt2) && echo \"$out\" && test \"$out\" = unsat"],
          # Everything the BSD cvc5 does still works: NRA through LibPoly.
          ["/bin/bash", "-c", "printf '(set-logic QF_NRA)\\n(declare-const x Real)\\n(assert (= (* x x) 2.0))\\n(assert (> x 0.0))\\n(check-sat)\\n' > /tmp/nra.smt2 && out=$(cvc5-ff /tmp/nra.smt2) && echo \"$out\" && test \"$out\" = sat"],
        ],
      } | Test,
  },
} | BuildSpec
