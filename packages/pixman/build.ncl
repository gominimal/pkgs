let { BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "0.46.4" in
{
  name = "pixman",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://www.cairographics.org/releases/pixman-0.46.4.tar.gz
      url = "gs://minimal-staging-archives/pixman-%{version}.tar.gz",
      sha256 = "d09c44ebc3bd5bee7021c79f922fe8fb2fb57f7320f55e97ff9914d2346a591c",
      extract = true,
      strip_prefix = "pixman-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    ninja,
    meson,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libpixman*.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },
  attrs.upstream_version = version,
  attrs.license_spdx = "MIT",

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
              gcc -x c - -o t -x none -I/usr/include/pixman-1 -lpixman-1 <<'EOF'
              #include <stdio.h>
              #include <pixman.h>
              int main(void) {
                uint32_t bits[16 * 16];
                pixman_image_t *img = pixman_image_create_bits(PIXMAN_a8r8g8b8, 16, 16, bits, 16 * 4);
                pixman_color_t red = {0xffff, 0, 0, 0xffff};
                pixman_box32_t box = {0, 0, 16, 16};
                pixman_image_fill_boxes(PIXMAN_OP_SRC, img, &red, 1, &box);
                printf("pixman %s px=%08x\n", pixman_version_string(), bits[0]);
                pixman_image_unref(img);
                return bits[0] != 0xffff0000u;
              }
              EOF
              ./t
            "%%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
