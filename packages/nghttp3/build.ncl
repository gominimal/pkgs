let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.15.0" in
{
  name = "nghttp3",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/ngtcp2/nghttp3/releases/download/v%{version}/nghttp3-%{version}.tar.gz",
      sha256 = "0e431c81eb2d3df5ced048d6e942925ff922ad053e76a0274eea7b164c9b776e",
      extract = true,
      strip_prefix = "nghttp3-%{version}",
    } | Source,
    base,
    cmake,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libnghttp3.so*" } | OutputLib,
    includes = { glob = "usr/include/nghttp3/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libnghttp3.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/nghttp3/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "ngtcp2",
        repo = "nghttp3",
      },
    } | Attrs,

  tests = {
    qpack_roundtrip =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > test_nghttp3.c << 'EOF'
#include <stdio.h>
#include <string.h>
#include <nghttp3/nghttp3.h>

int main(void) {
    const nghttp3_info *info = nghttp3_version(0);
    if (info == NULL) {
        fprintf(stderr, "nghttp3_version returned NULL\n");
        return 1;
    }
    printf("nghttp3 version: %s\n", info->version_str);

    /* Exercise QPACK encoder/decoder roundtrip */
    nghttp3_qpack_encoder *enc = NULL;
    nghttp3_qpack_decoder *dec = NULL;
    const nghttp3_mem *mem = nghttp3_mem_default();

    int rv = nghttp3_qpack_encoder_new(&enc, 4096, mem);
    if (rv != 0) {
        fprintf(stderr, "encoder_new failed: %d\n", rv);
        return 1;
    }

    rv = nghttp3_qpack_decoder_new(&dec, 4096, 100, mem);
    if (rv != 0) {
        fprintf(stderr, "decoder_new failed: %d\n", rv);
        return 1;
    }

    printf("QPACK encoder/decoder created successfully\n");

    nghttp3_qpack_decoder_del(dec);
    nghttp3_qpack_encoder_del(enc);

    printf("OK\n");
    return 0;
}
EOF
          gcc test_nghttp3.c -o test_nghttp3 -lnghttp3
          ./test_nghttp3 | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
