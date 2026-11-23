let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let gperf = import "../gperf/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "2.6.2" in
{
  name = "libseccomp",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/seccomp/libseccomp/releases/download/v%{version}/libseccomp-%{version}.tar.gz",
      sha256 = "6b845d352c6d7887d8d134c43d86850d40f5dcee11ad1675c18197ae4d869d42",
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
      license_spdx = "LGPL-2.1-only",
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
        test_deps = [bash-bootstrap, toolchain, coreutils, grep],
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
        test_deps = [bash-bootstrap],
        cmds = [
          # read is syscall 0 on x86_64 and 63 on aarch64 (the generic table);
          # -a picks the ABI, so the answer is the same on either build host.
          ["/bin/bash", "-c", "x=$(scmp_sys_resolver -a x86_64 read); a=$(scmp_sys_resolver -a aarch64 read); echo \"x86_64=$x aarch64=$a\"; [[ $x == 0 && $a == 63 ]]"],
        ],
      } | Test,
  },
} | BuildSpec
