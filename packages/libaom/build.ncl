let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "3.15.3" in
{
  name = "libaom",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://storage.googleapis.com/aom-releases/libaom-%{version}.tar.gz",
      sha256 = "12c01dc731ed7b5a999e28120b45bf58a002ba3435a4ba2cfbc1e084a27c9c04",
      extract = true,
      strip_prefix = "libaom-%{version}",
    } | Source,
    base,
    toolchain,
    cmake,
    make,
    perl,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libaom.so*" } | OutputLib,
    includes = { glob = "usr/include/aom/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause",
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
              gcc -x c - -o t -laom <<'EOF'
              #include <aom/aom_codec.h>
              int main(void) { return aom_codec_version() > 0 && aom_codec_version_str()[0] ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
