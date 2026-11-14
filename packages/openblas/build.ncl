let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let { target, .. } = import "config.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in

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
    # TODO(readelf): unverified DT_NEEDED. Without NOFORTRAN, OpenBLAS builds
    # LAPACK with gfortran, so libopenblas.so should NEED libgfortran.so.5, and
    # on amd64 libgfortran NEEDs libquadmath.so.0 (gcc builds no libquadmath on
    # arm64). Replaces gcc's catch-all `libs` output (inbox#1261).
    subsetOf
      gcc-runtime
      (
        ["libgcc", "libgfortran"]
        @ match {
          { arch = 'Amd64, .. } => ["libquadmath"],
          { arch = 'Arm64, .. } => [],
        } target
      ),
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
