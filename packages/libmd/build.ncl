let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.3.0" in
{
  name = "libmd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://archive.hadrons.org/software/libmd/libmd-%{version}.tar.xz",
      sha256 = "fc0f1eb6b6766470326f2c014693809190e67dba84274a6fbae9d4912d066706",
      extract = true,
      strip_prefix = "libmd-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [glibc],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libmd.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "libmd",
      license_spdx = "BSD-2-Clause AND BSD-3-Clause AND ISC AND Beerware AND LicenseRef-Public-Domain",
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
              gcc -x c - -o t -lmd <<'EOF'
              #include <sys/types.h>
              #include <md5.h>
              #include <string.h>
              int main(void) { char out[MD5_DIGEST_STRING_LENGTH]; MD5Data((const unsigned char *)"abc", 3, out);
                return strcmp(out, "900150983cd24fb0d6963f7d28e17f72") == 0 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
