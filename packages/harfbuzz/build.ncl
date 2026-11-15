let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let meson = import "../meson/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in

let freetype = import "../freetype/build.ncl" in
let glib = import "../glib/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# 15.0.0 is the first release with the GHSA-r62p-jr5f-3mjm fix (subsetter
# out-of-bounds read via unsanitized substitute FeatureParams; affected
# >= 5.3.0, <= 14.6.0). Fix commits 4a60bf8333 + a1d34fedce (harfbuzz#6413)
# are ancestors of 15.0.0 and of no 14.x tag. build.sh fails the build if the
# fix regresses (ghsa-r62p-check.c, upstream's own regression vector).
let version = "15.1.0" in
{
  name = "harfbuzz",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "ghsa-r62p-check.c" } | Local,
    {
      url = "gs://minimal-staging-archives/harfbuzz-%{version}.tar.xz",
      sha256 = "0fc7c565443a5f4be7da65ac5ee5bd737d9b158dc908708b7689a0a5796b0c8d",
      extract = true,
      strip_prefix = "harfbuzz-%{version}",
    } | Source,
    base,
    meson,
    ninja,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    freetype,
    glib,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libharfbuzz*.so*" } | OutputLib,
    includes = { glob = "usr/include/harfbuzz/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
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
              gcc -x c - -o t -lharfbuzz <<'EOF'
              #include <harfbuzz/hb.h>
              int main(void) { hb_buffer_t *b = hb_buffer_create(); hb_buffer_add_utf8(b, "abc", -1, 0, -1);
                int ok = hb_buffer_get_length(b) == 3 && hb_version_string()[0] != 0; hb_buffer_destroy(b); return ok ? 0 : 1; }
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
      license_spdx = "MIT-Modern-Variant",
      source_provenance = {
        category = 'GithubRepo,
        owner = "harfbuzz",
        repo = "harfbuzz",
      },
    } | Attrs,
} | BuildSpec
