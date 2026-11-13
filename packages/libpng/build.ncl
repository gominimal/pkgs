let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.6.59" in
{
  name = "libpng",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # https://downloads.sourceforge.net/project/libpng/libpng16/1.6.59/libpng-1.6.59.tar.xz
      url = "gs://minimal-staging-archives/libpng-%{version}.tar.xz",
      sha256 = "d80dd2a38a37f803cb9b6ac7b14bd6e74ddc3b654780a8380bdf93523fdb4389",
      extract = true,
      strip_prefix = "libpng-%{version}",
    } | Source,
    base,
    toolchain,
    make,
  ],
  runtime_deps = [
    glibc,
    zlib,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libpng*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "libpng-2.0",
      repology_project = "libpng",
      source_provenance = {
        category = 'GithubRepo,
        owner = "pnggroup",
        repo = "libpng",
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
              gcc -x c - -o t -lpng <<'EOF'
              #include <png.h>
              int main(void) { png_structp p = png_create_read_struct(PNG_LIBPNG_VER_STRING, 0, 0, 0); if (!p) return 1;
                png_destroy_read_struct(&p, 0, 0); return png_access_version_number() > 0 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
