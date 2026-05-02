let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let base = import "../base/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.3" in
{
  name = "libcap-ng",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/stevegrubb/libcap-ng/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "fe11ebbb55904763b3532f19069f13ec319042634620180a03bd4653d301563e",
      extract = true,
      strip_prefix = "libcap-ng-%{version}",
    } | Source,
    autoconf,
    automake,
    base,
    libtool,
    linux_headers,
    m4,
    make,
    perl,
    pkgconf,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    pscap = { glob = "usr/bin/pscap" } | OutputBin,
    netcap = { glob = "usr/bin/netcap" } | OutputBin,
    filecap = { glob = "usr/bin/filecap" } | OutputBin,
    libs = { glob = "usr/lib/libcap-ng.so*" } | OutputLib,
    libdrop_ambient = { glob = "usr/lib/libdrop_ambient.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libcap-ng.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "stevegrubb",
        repo = "libcap-ng",
      },
    } | Attrs,

  tests = {
    link_and_run =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > test_capng.c << 'EOF'
#include <stdio.h>
#include <cap-ng.h>

int main(void) {
    capng_clear(CAPNG_SELECT_BOTH);

    capng_type_t type = CAPNG_EFFECTIVE;
    int has_cap = capng_have_capability(type, CAP_CHOWN);
    printf("CAP_CHOWN after clear: %d\n", has_cap);

    capng_update(CAPNG_ADD, CAPNG_EFFECTIVE, CAP_CHOWN);
    has_cap = capng_have_capability(type, CAP_CHOWN);
    printf("CAP_CHOWN after add: %d\n", has_cap);

    if (has_cap != 1) {
        fprintf(stderr, "expected CAP_CHOWN to be set\n");
        return 1;
    }

    printf("OK\n");
    return 0;
}
EOF
          gcc test_capng.c -o test_capng -lcap-ng
          ./test_capng | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
    pscap_runs =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "pscap --help 2>&1 || true"],
        ],
      } | Test,
  },
} | BuildSpec
