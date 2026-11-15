let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let xorgproto = import "../xorgproto/build.ncl" in

let libxfixes = import "../libxfixes/build.ncl" in
let libx11 = import "../libx11/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.1.7" in
{
  name = "libxdamage",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libXdamage-%{version}.tar.xz",
      sha256 = "127067f521d3ee467b97bcb145aeba1078e2454d448e8748eb984d5b397bde24",
      extract = true,
      strip_prefix = "libXdamage-%{version}",
    } | Source,
    base,
    make,
    toolchain,
    pkgconf,
    xorgproto,
  ],
  runtime_deps = [
    libxfixes,
    libx11,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libXdamage.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "HPND-sell-variant",
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
              gcc -x c - -o t -lXdamage <<'EOF'
              #include <X11/extensions/Xdamage.h>
              int main(void) { void *volatile p = (void *)XDamageCreate; return p ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
