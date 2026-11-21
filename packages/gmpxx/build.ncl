# GMP's C++ interface (libgmpxx, gmpxx.h). gmp itself is in gcc's build graph,
# so it cannot depend on gcc-runtime (gcc_runtime_guard.py rule 4) and is built
# --disable-cxx; the C++ part, which needs libstdc++, lives here. build.sh
# builds the same gmp release with --enable-cxx and keeps only the C++ files,
# so no path is shipped by both packages. It fails if this version and the gmp
# build dep's differ: bump the two together.
let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let gmp = import "../gmp/build.ncl" in
let make = import "../make/build.ncl" in
let m4 = import "../m4/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let version = "6.3.0" in
{
  name = "gmpxx",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gmp-%{version}.tar.xz",
      sha256 = "a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898"
    } | Source,
    base,
    gmp,
    m4,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    gmp,
    subsetOf gcc-runtime ["libstdcpp", "libgcc"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    libgmpxx = { glob = "usr/lib/libgmpxx.so*" } | OutputLib,
    includes = { glob = "usr/include/gmpxx.h" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/gmpxx.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-3.0-or-later OR GPL-2.0-or-later",
      repology_project = "gmp",
      source_provenance = {
        category = 'GnuProject,
        name = "gmp",
      },
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              g++ -x c++ - -o t -lgmpxx -lgmp <<'EOF'
              #include <gmpxx.h>
              int main() { mpz_class a = 2; a = a * a * a; return a == 8 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
