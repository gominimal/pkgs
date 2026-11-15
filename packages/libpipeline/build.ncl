let { BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let version = "1.5.8" in
{
  name = "libpipeline",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://download.savannah.gnu.org/releases/libpipeline/libpipeline-%{version}.tar.gz
      url = "gs://minimal-staging-archives/libpipeline-%{version}.tar.gz",
      sha256 = "1b1203ca152ccd63983c3f2112f7fe6fa5afd453218ede5153d1b31e11bb8405",
    } | Source,
    base,
    toolchain,
    make,
    pkgconf,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    pkgconf = { glob = "usr/lib/pkgconfig/libpipeline.pc" } | OutputData,
    includes = { glob = "usr/include/*.h" } | OutputData,
    docs = { glob = "usr/share/man/man3/*" } | OutputData,
  },
  attrs = {
    upstream_version = version,
    license_spdx = "GPL-3.0-only",
  },

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              gcc -x c - -o t -lpipeline <<'EOF'
              #include <pipeline.h>
              int main(void) { pipeline *p = pipeline_new(); if (!p) return 1; pipeline_free(p); return 0; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
