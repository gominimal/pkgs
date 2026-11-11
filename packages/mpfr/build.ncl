let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# other
let m4 = import "../m4/build.ncl" in
let gmp = import "../gmp/build.ncl" in

let version = "4.2.2" in
{
  name = "mpfr",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mpfr-%{version}.tar.xz",
      sha256 = "b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01"
    } | Source,
    # base
    bash-bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk-bootstrap,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    glibc,
    linux_headers,
    # other
    m4,
  ],
  runtime_deps = [
    glibc,
    gmp,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libmpfr.so*" } | OutputLib,
    ltconfigs = { glob = "usr/lib/libmpfr.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    infos = { glob = "usr/share/info/*.info" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "mpfr (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/a1075a07df77332ba904185413f9ba8640371fee0c1e4d82e30d404bd2b2581e/mpfr-x86_64.tar.zst",
              sha256 = "a1075a07df77332ba904185413f9ba8640371fee0c1e4d82e30d404bd2b2581e",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/f3ad85a09f71c587e74344d2d1d6b8dc6523d350d2e19cb08f16a87c0b3ec76f/mpfr-aarch64.tar.zst",
              sha256 = "f3ad85a09f71c587e74344d2d1d6b8dc6523d350d2e19cb08f16a87c0b3ec76f",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "mpfr",
      },
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
              gcc -x c - -o t -x none -lmpfr -lgmp <<'EOF'
              #include <stdio.h>
              #include <mpfr.h>
              int main(void) {
                mpfr_t x;
                mpfr_init2(x, 200);
                mpfr_sqrt_ui(x, 2, MPFR_RNDN);
                double d = mpfr_get_d(x, MPFR_RNDN);
                printf("mpfr %s sqrt2=%.15f\n", mpfr_get_version(), d);
                mpfr_clear(x);
                return !(d > 1.41421356 && d < 1.41421357);
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
