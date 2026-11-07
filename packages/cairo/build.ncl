let { BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let libpng = import "../libpng/build.ncl" in
let pixman = import "../pixman/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.18.6" in
{
  name = "cairo",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://www.cairographics.org/releases/cairo-1.18.6.tar.xz
      url = "gs://minimal-staging-archives/cairo-%{version}.tar.xz",
      sha256 = "1c767308174337a74694da0f3ec069c271452163a1ef4540964c50c301f157d4",
      extract = true,
      strip_prefix = "cairo-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    ninja,
    meson,
    pkgconf,
  ],
  runtime_deps = [
    libpng,
    pixman,
    fontconfig,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/{,cairo/}libcairo*.so*" } | OutputLib,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
  attrs.license_spdx = "LGPL-2.1-only OR MPL-1.1",

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
              gcc -x c - -o t -lcairo <<'EOF'
              #include <cairo/cairo.h>
              int main(void) { cairo_surface_t *s = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 4, 4);
                int ok = cairo_surface_status(s) == CAIRO_STATUS_SUCCESS && cairo_version() > 0;
                cairo_surface_destroy(s); return ok ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
