let { subsetOf, Attrs, BuildSpec, Local, OutputLib, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# libgfortran as its own package (gominimal/inbox#1261), so gcc-runtime stays
# small for the many closures that never load Fortran code. Depend on
# `subsetOf gcc-runtime-fortran ["libgfortran"]`. Not on gcc's bootstrap cycle
# (its only consumer, openblas, is not), so it needs no replace_on_cycle.
# No upstream_version: this follows the gcc build dep and rebuilds with it.
{
  name = "gcc-runtime-fortran",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage.sh" } | Local,
    bash-bootstrap,
    coreutils,
    gcc,
  ],
  runtime_deps = [
    glibc,
    # libgfortran NEEDs libgcc_s, and libquadmath on amd64 (gcc builds no
    # libquadmath on arm64).
    subsetOf
      gcc-runtime
      (
        ["libgcc"]
        @ match {
          { arch = 'Amd64, .. } => ["libquadmath"],
          { arch = 'Arm64, .. } => [],
        } target
      ),
  ],

  cmd = "./build.sh",
  outputs = {
    libgfortran = { glob = "usr/lib/libgfortran.so*" } | OutputLib,
  },

  attrs =
    {
      license_spdx = "GPL-3.0-or-later WITH GCC-exception-3.1",
    } | Attrs,

  tests = {
    # No gcc in this closure (bash-bootstrap needs only glibc), so libgfortran
    # must resolve every DT_NEEDED against gcc-runtime-fortran, gcc-runtime and
    # glibc alone.
    loads_without_gcc =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/bin/bash",
            "-c",
            "shopt -s nullglob; ld=(/usr/lib/ld-linux*.so.*); [ ${#ld[@]} -eq 1 ] || exit 3; l=/usr/lib/libgfortran.so.5; [ -e \"$l\" ] || exit 4; out=$(\"${ld[0]}\" --list \"$l\") || exit 5; [[ $out == *'not found'* ]] && exit 6; exit 0",
          ],
        ],
      } | Test,
  },
} | BuildSpec
