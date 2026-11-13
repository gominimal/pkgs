let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let which = import "../which/build.ncl" in
let gmp = import "../gmp/build.ncl" in

# CoCoALib (John Abbott, Anna M. Bigatti et al.): the C++ library behind
# CoCoA-5, for computations in commutative algebra. cvc5 uses its Groebner
# bases for the finite-field theory (QF_FF); it is here for `cvc5-ff`.
#
# cvc5 1.4.2 pins exactly this release (cmake/FindCoCoA.cmake: 0.99850, the
# same sha256 as below) AND patches it: `cvc5-trace.patch` is cvc5's
# cmake/deps-utils/CoCoALib-0.99850-trace.patch, copied verbatim from the
# cvc5-1.4.2 tag. It adds Groebner-basis reduction hooks (`handlersEnabled`,
# off by default) that cvc5's FF proof tracing calls, plus configure-script
# fixes. cvc5 refuses an unpatched CoCoALib: FindCoCoA.cmake try_compiles a
# probe of `CoCoA::handlersEnabled`. Bump the two together.
#
# Static library only: CoCoALib's build has no shared-library target.
let version = "0.99850" in
{
  name = "cocoalib",

  build_deps = [
    { file = "build.sh" } | Local,
    { file = "cvc5-trace.patch" } | Local,
    {
      # Mirror of https://cocoa.altervista.org/cocoalib/tgz/CoCoALib-0.99850.tgz
      # (also cvc5's own copy, github.com/cvc5/cvc5-deps; same sha256).
      url = "gs://minimal-staging-archives/cocoalib/CoCoALib-%{version}.tgz",
      sha256 = "d3e7af0153c6950f83f4e3556540f0177fedf5179f0f7667b7d6d670268fd445",
      extract = true,
      strip_prefix = "CoCoALib-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    patch,
    # configuration/verify-compiler.sh resolves the compiler with `which`.
    which,
    gmp,
  ],

  # A static archive: nothing to load at runtime. Whoever links it links GMP.
  runtime_deps = [],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libcocoa.a" } | OutputLib,
    includes = { glob = "usr/include/CoCoA/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # COPYRIGHT-full-text is the GPL v3; README: "The source code files
      # under src/ and include/ are distributed under the GPL (version 3, or
      # later)", and every source header says so. Strong copyleft, and the
      # library is static: anything linking it is a GPL-3.0-or-later combined
      # work (cvc5's COPYING lists CoCoALib among its "OPTIONAL GPLv3
      # libraries"). Tier C in the FV licence policy (pkgmgr-rs#1181): only
      # for standalone GPL programs such as `cvc5-ff`, never the default cvc5.
      license_spdx = "GPL-3.0-or-later",
      source_provenance = {
        category = 'Website,
        homepage = "https://cocoa.altervista.org/cocoalib/",
        downloads_page = "https://cocoa.altervista.org/cocoalib/tgz/",
      },
    } | Attrs,

  tests = {
    # Links against libcocoa.a and computes: the reduced Groebner basis of
    # <x^2 - y, x*y - 1> over QQ (lex, x > y) is {x - y^2, y^3 - 1}. Also
    # checks cvc5's patch is in (the hook global exists and is off).
    groebner =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, gmp],
        cmds = [
          ["/bin/bash", "-c", "printf '#include \"CoCoA/library.H\"\\n#include \"CoCoA/TmpGPoly.H\"\\n#include <iostream>\\nusing namespace CoCoA;\\nint main(){ GlobalManager CoCoAFoundations; if (CoCoA::handlersEnabled) return 2; ring P = NewPolyRing(RingQQ(), symbols(\"x,y\"), lex); ideal I = ideal(RingElem(P, \"x^2-y\"), RingElem(P, \"x*y-1\")); std::cout << ReducedGBasis(I) << std::endl; return 0; }\\n' > /tmp/t.C && g++ -std=c++14 /tmp/t.C -o /tmp/t -lcocoa -lgmp && out=$(/tmp/t) && echo \"$out\" && test \"$out\" = '[x -y^2,  y^3 -1]'"],
        ],
      } | Test,
  },
} | BuildSpec
