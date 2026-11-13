let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

# LibPoly (SRI-CSL): polynomial arithmetic and real algebraic numbers. cvc5
# uses it for its complete nonlinear-real-arithmetic procedure
# (cylindrical algebraic coverings, `--nl-cov`), ICP and exact algebraic
# model values. cvc5 1.4.2 pins exactly this release (cmake/FindPoly.cmake:
# v0.2.1, same sha256 as below).
let version = "0.2.1" in
{
  name = "libpoly",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/SRI-CSL/libpoly/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "f9920afc876f998633348b9cbfcf180757ada48cc872040256c60ad0707b5a0f",
      extract = true,
      strip_prefix = "libpoly-%{version}",
    } | Source,
    base,
    toolchain,
    cmake,
    ninja,
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
  },

  outputs = {
    # Shared only (libpoly.so.0, libpolyxx.so.0): consumers link it
    # dynamically, which is what keeps them out of the LGPL's
    # combined-work terms (see license_spdx).
    libs = { glob = "usr/lib/libpoly{,xx}.so*" } | OutputLib,
    includes = { glob = "usr/include/poly/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      # LICENCE is the LGPL v3; every source header says "either version 3
      # of the License, or (at your option) any later version". Weak
      # copyleft, the same terms as gmp: a program that links the shared
      # library keeps its own licence (cvc5's COPYING lists LibPoly among
      # the libraries that do not affect cvc5's BSD terms).
      license_spdx = "LGPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "SRI-CSL",
        repo = "libpoly",
      },
    } | Attrs,

  tests = {
    # The library links and computes through the C API: x^2 - 2 has exactly
    # two real roots (+-sqrt 2), isolated as algebraic numbers.
    links_and_runs =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, gmp],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <poly/poly.h>\\n#include <poly/upolynomial.h>\\n#include <poly/algebraic_number.h>\\n#include <stdio.h>\\nint main(void){ lp_integer_t c[3]; lp_integer_construct_from_int(lp_Z, &c[0], -2); lp_integer_construct_from_int(lp_Z, &c[1], 0); lp_integer_construct_from_int(lp_Z, &c[2], 1); lp_upolynomial_t* p = lp_upolynomial_construct(lp_Z, 2, c); lp_algebraic_number_t roots[2]; size_t n = 0; lp_upolynomial_roots_isolate(p, roots, &n); printf(\"%%zu\\\\n\", n); return n == 2 ? 0 : 1; }\\n' > /tmp/t.c && gcc /tmp/t.c -o /tmp/t -lpoly -lgmp && /tmp/t"],
        ],
      } | Test,
  },
} | BuildSpec
