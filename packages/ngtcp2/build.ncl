let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let openssl = import "../openssl/build.ncl" in

let version = "1.22.1" in
{
  name = "ngtcp2",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ngtcp2/ngtcp2/releases/download/v%{version}/ngtcp2-%{version}.tar.gz",
      sha256 = "063d80531acac0ddbbc1b9d12829a824edc2abe8dba2e632fd1ce15cfd5632f9",
      extract = true,
      strip_prefix = "ngtcp2-%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
    pkgconf,
    openssl,
  ],
  runtime_deps = [
    glibc,
    openssl,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libngtcp2*.so*" } | OutputLib,
    includes = { glob = "usr/include/ngtcp2/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libngtcp2*.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/ngtcp2/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ngtcp2",
        repo = "ngtcp2",
      },
    } | Attrs,

  tests = {
    settings_init =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > test_ngtcp2.c << 'EOF'
#include <stdio.h>
#include <ngtcp2/ngtcp2.h>

int main(void) {
    const ngtcp2_info *info = ngtcp2_version(0);
    if (info == NULL) {
        fprintf(stderr, "ngtcp2_version returned NULL\n");
        return 1;
    }
    printf("ngtcp2 version: %s\n", info->version_str);

    /* Exercise settings initialization */
    ngtcp2_settings settings;
    ngtcp2_settings_default(&settings);

    ngtcp2_transport_params params;
    ngtcp2_transport_params_default(&params);

    printf("max_udp_payload_size: %lu\n",
           (unsigned long)params.max_udp_payload_size);
    printf("OK\n");
    return 0;
}
EOF
          gcc test_ngtcp2.c -o test_ngtcp2 -lngtcp2
          ./test_ngtcp2 | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
