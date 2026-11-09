let { BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "1.0.30" in
{
  name = "libusb",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libusb/libusb/releases/download/v%{version}/libusb-%{version}.tar.bz2",
      sha256 = "fea36f34f9156400209595e300840767ab1a385ede1dc7ee893015aea9c6dbaf",
      extract = true,
      strip_prefix = "libusb-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libusb-1.0.so*" } | OutputLib,
    headers = { glob = "usr/include/libusb-1.0/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libusb-1.0.pc" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "LGPL-2.1-or-later",
    source_provenance = {
      category = 'GithubRepo,
      owner = "libusb",
      repo = "libusb",
    },
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
              gcc -x c - -o t -lusb-1.0 <<'EOF'
              #include <libusb-1.0/libusb.h>
              int main(void) { const struct libusb_version *v = libusb_get_version(); return v->major == 1 ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
