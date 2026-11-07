let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.0.0" in
{
  name = "libfdk-aac",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.sourceforge.net/project/opencore-amr/fdk-aac/fdk-aac-%{version}.tar.gz",
      sha256 = "70b95857b958fb8f794489307a87845dde4cc1fcea060f3f29f40e4b2fe16c82",
      extract = true,
      strip_prefix = "fdk-aac-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libfdk-aac.so*" } | OutputLib,
    includes = { glob = "usr/include/fdk-aac/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'Sourceforge,
        name = "opencore-amr",
      },
      license_spdx = "FDK-AAC",
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
            m%%"
              set -e
              gcc -x c - -o t -lfdk-aac <<'EOF'
              #include <fdk-aac/aacenc_lib.h>
              int main(void) { HANDLE_AACENCODER h; if (aacEncOpen(&h, 0, 2) != AACENC_OK) return 1; aacEncClose(&h); return 0; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
