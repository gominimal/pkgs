let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.6.1" in
{
  name = "libopus",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://downloads.xiph.org/releases/opus/opus-%{version}.tar.gz",
      sha256 = "6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1",
      extract = true,
      strip_prefix = "opus-%{version}",
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
    libs = { glob = "usr/lib/libopus.so*" } | OutputLib,
    includes = { glob = "usr/include/opus/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "xiph",
        repo = "opus",
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
            m%%"
              set -e
              gcc -x c - -o t -lopus <<'EOF'
              #include <opus/opus.h>
              int main(void) { int err; OpusEncoder *e = opus_encoder_create(48000, 2, OPUS_APPLICATION_AUDIO, &err);
                if (err != OPUS_OK || !opus_get_version_string()[0]) return 1; opus_encoder_destroy(e); return 0; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
