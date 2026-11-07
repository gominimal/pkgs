let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in
let xtrans = import "../xtrans/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# X Inter-Client Exchange library (libICE.so.6): the session-management transport libSM and libXt
# sit on. Deps from libICE's pkg-config: `Requires.private: xproto`, plus xtrans for the transport
# headers.
let version = "1.1.2" in
{
  name = "libice",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libICE-%{version}.tar.xz",
      sha256 = "974e4ed414225eb3c716985df9709f4da8d22a67a2890066bc6dfc89ad298625",
      extract = true,
      strip_prefix = "libICE-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
    xtrans,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libICE.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain, xorgproto],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              export HOME=/tmp
              gcc -x c - -o t -lICE <<'EOF'
              #include <X11/ICE/ICElib.h>
              #include <X11/ICE/ICEutil.h>
              int main(void) { return IceAuthFileName() != 0 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
