let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let meson = import "../meson/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "2.4.134" in
{
  name = "libdrm",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/libdrm-%{version}.tar.xz",
      sha256 = "ac5e74d157830eb8bee44c6a6bf3ad49774ef0dd2a72bdad74a8f20308b52a95",
      extract = true,
      strip_prefix = "libdrm-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libdrm*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  tests = {
    # No /dev/dri in the sandbox, so exercise libdrm's device-free format helpers
    # (xf86drm.c:5236-5311). The modifier names come from tables generated at build time
    # from drm_fourcc.h by gen_table_fourcc.py, so a broken build or header install fails
    # here. Compiles against the installed headers (-I/usr/include/libdrm, as libdrm.pc's
    # Cflags say), so the constants are libdrm's own, not copied numbers.
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              gcc -I/usr/include/libdrm -x c - -o t -ldrm <<'EOF'
              #include <stdio.h>
              #include <stdlib.h>
              #include <string.h>
              #include <xf86drm.h>
              #include <drm_fourcc.h>
              static int check(const char *what, char *got, const char *want) {
                printf("%s = %s (want %s)\n", what, got ? got : "(null)", want);
                int bad = got == NULL || strcmp(got, want) != 0;
                free(got);
                return bad;
              }
              int main(void) {
                int bad = 0;
                bad |= check("drmGetFormatName(DRM_FORMAT_XRGB8888)",
                             drmGetFormatName(DRM_FORMAT_XRGB8888), "XR24");
                bad |= check("drmGetFormatName(DRM_FORMAT_XRGB8888 | DRM_FORMAT_BIG_ENDIAN)",
                             drmGetFormatName(DRM_FORMAT_XRGB8888 | DRM_FORMAT_BIG_ENDIAN), "XR24_BE");
                bad |= check("drmGetFormatModifierName(DRM_FORMAT_MOD_LINEAR)",
                             drmGetFormatModifierName(DRM_FORMAT_MOD_LINEAR), "LINEAR");
                bad |= check("drmGetFormatModifierName(I915_FORMAT_MOD_X_TILED)",
                             drmGetFormatModifierName(I915_FORMAT_MOD_X_TILED), "X_TILED");
                bad |= check("drmGetFormatModifierVendor(I915_FORMAT_MOD_X_TILED)",
                             drmGetFormatModifierVendor(I915_FORMAT_MOD_X_TILED), "INTEL");
                if (bad) return 1;
                puts("OK");
                return 0;
              }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
    } | Attrs,
} | BuildSpec
