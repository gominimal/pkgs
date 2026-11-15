let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in

let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libmd = import "../libmd/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.12.2" in
{
  name = "libbsd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://libbsd.freedesktop.org/releases/libbsd-%{version}.tar.xz",
      sha256 = "b88cc9163d0c652aaf39a99991d974ddba1c3a9711db8f1b5838af2a14731014",
      extract = true,
      strip_prefix = "libbsd-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [glibc, libmd],
  cmd = "./build.sh",
  outputs = {
    # libbsd.so is a linker script (it pulls in libmd as needed), not an ELF binary.
    # libbsd-ctor.a installs despite --disable-static; libbsd-ctor.pc names it.
    libs = { glob = "usr/lib/libbsd*.{a,so*}", allow_data = true } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "libbsd",
      license_spdx = "BSD-2-Clause AND BSD-3-Clause AND ISC AND MIT AND Beerware AND LicenseRef-Public-Domain",
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
              gcc -x c - -o t -lbsd <<'EOF'
              #include <bsd/string.h>
              int main(void) { char b[4]; return strlcpy(b, "hello", sizeof b) == 5 && b[3] == 0 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
