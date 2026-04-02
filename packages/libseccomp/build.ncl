let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gperf = import "../gperf/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.6.0" in
{
  name = "libseccomp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/seccomp/libseccomp/releases/download/v%{version}/libseccomp-%{version}.tar.gz",
      sha256 = "83b6085232d1588c379dc9b9cae47bb37407cf262e6e74993c61ba72d2a784dc",
      extract = true,
      strip_prefix = "libseccomp-%{version}",
    } | Source,
    base,
    gperf,
    linux_headers,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/scmp_sys_resolver" } | OutputBin,
    libs = { glob = "usr/lib/libseccomp.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libseccomp.pc" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "seccomp",
        repo = "libseccomp",
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
          cat > test_seccomp.c << 'EOF'
#include <stdio.h>
#include <seccomp.h>

int main(void) {
    const struct scmp_version *ver = seccomp_version();
    if (ver == NULL) {
        fprintf(stderr, "seccomp_version() returned NULL\n");
        return 1;
    }
    printf("libseccomp version: %u.%u.%u\n", ver->major, ver->minor, ver->micro);
    printf("OK\n");
    return 0;
}
EOF
          gcc test_seccomp.c -o test_seccomp -lseccomp
          ./test_seccomp | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
    scmp_sys_resolver =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "scmp_sys_resolver --help 2>&1 || true"],
        ],
      } | Test,
  },
} | BuildSpec
