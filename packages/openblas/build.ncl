let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc-runtime-fortran = import "../gcc-runtime-fortran/build.ncl" in

let version = "0.3.34" in
{
  name = "openblas",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/OpenMathLib/OpenBLAS/v%{version}.tar.gz",
      sha256 = "cd7e129868320cc2d033afa920e31202dfe0b8066a5b66661900ccc0f197dfed",
      extract = true,
      strip_prefix = "OpenBLAS-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    # libopenblasp-r0.3.34.so NEEDs libgfortran.so.5, libm, libc and the
    # loader, on both arches (readelf on the gcc 15 and gcc 16 builds, pkgs#1340
    # run d168779c): LAPACK is built with gfortran, and the pthreads build uses
    # no libgomp. libgfortran's own libgcc_s (and libquadmath on amd64) come
    # with gcc-runtime-fortran. Replaces gcc's catch-all `libs` (inbox#1261).
    subsetOf gcc-runtime-fortran ["libgfortran"],
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libopenblas*.{a,so*}" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/openblas/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      repology_project = "openblas",
      source_provenance = {
        category = 'GithubRepo,
        owner = "OpenMathLib",
        repo = "OpenBLAS",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              set -e
              cd /tmp
              gcc -x c - -o t -x none -lopenblas <<'EOF'
              #include <stdio.h>
              #include <cblas.h>
              int main(void) {
                double x[3] = {1, 2, 3}, y[3] = {4, 5, 6};
                double d = cblas_ddot(3, x, 1, y, 1);
                printf("%s ddot=%f\n", openblas_get_config(), d);
                return d != 32.0;
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
