let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let harfbuzz = import "../harfbuzz/build.ncl" in
let fribidi = import "../fribidi/build.ncl" in
let glib = import "../glib/build.ncl" in
let fontconfig = import "../fontconfig/build.ncl" in
let freetype = import "../freetype/build.ncl" in
let cairo = import "../cairo/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.58.2" in
{
  name = "pango",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/pango-%{version}.tar.xz",
      sha256 = "342385b6ca3b7c73455d7c80a13b7dbe4489e00bc3bd4c5bd6ed4dce421e374a",
      extract = true,
      strip_prefix = "pango-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    harfbuzz,
    fribidi,
    glib,
    fontconfig,
    freetype,
    cairo,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libpango*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-2.0-only",
    } | Attrs,

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain, pkgconf],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%%"
              set -e
              cd /tmp
              gcc -x c - -o t -x none $(pkg-config --cflags --libs pango) <<'EOF'
              #include <stdio.h>
              #include <pango/pango.h>
              int main(void) {
                PangoFontDescription *d = pango_font_description_from_string("Sans Bold 12");
                int ok = pango_font_description_get_weight(d) == PANGO_WEIGHT_BOLD &&
                         pango_font_description_get_size(d) == 12 * PANGO_SCALE;
                printf("pango %s\n", pango_version_string());
                pango_font_description_free(d);
                return !ok;
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
