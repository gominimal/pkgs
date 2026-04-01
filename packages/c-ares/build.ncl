let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.34.6" in
{
  name = "c-ares",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/c-ares/c-ares/releases/download/v%{version}/c-ares-%{version}.tar.gz",
      sha256 = "912dd7cc3b3e8a79c52fd7fb9c0f4ecf0aaa73e45efda880266a2d6e26b84ef5",
      extract = true,
      strip_prefix = "c-ares-%{version}",
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
    libs = { glob = "usr/lib/libcares.so*" } | OutputLib,
    includes = { glob = "usr/include/ares*.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/libcares.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/c-ares/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "c-ares",
        repo = "c-ares",
      },
    } | Attrs,

  tests = {
    resolve_init =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > test_cares.c << 'EOF'
#include <stdio.h>
#include <string.h>
#include <ares.h>

int main(void) {
    int rv = ares_library_init(ARES_LIB_INIT_ALL);
    if (rv != ARES_SUCCESS) {
        fprintf(stderr, "ares_library_init failed: %s\n", ares_strerror(rv));
        return 1;
    }
    printf("c-ares version: %s\n", ares_version(NULL));

    ares_channel_t *channel = NULL;
    struct ares_options opts;
    memset(&opts, 0, sizeof(opts));
    opts.timeout = 2000;
    opts.tries = 1;

    rv = ares_init_options(&channel, &opts, ARES_OPT_TIMEOUTMS | ARES_OPT_TRIES);
    if (rv != ARES_SUCCESS) {
        fprintf(stderr, "ares_init_options failed: %s\n", ares_strerror(rv));
        ares_library_cleanup();
        return 1;
    }

    printf("channel initialized successfully\n");

    ares_destroy(channel);
    ares_library_cleanup();

    printf("OK\n");
    return 0;
}
EOF
          gcc test_cares.c -o test_cares -lcares
          ./test_cares | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
