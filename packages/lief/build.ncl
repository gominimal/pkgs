let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "0.17.6" in
{
  name = "lief",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/lief-project/LIEF/archive/refs/tags/%{version}.tar.gz",
      sha256 = "5fbbd19c85912d417eabbaef2b98e70144496356964685b82e0792d708b9be87",
      extract = true,
      strip_prefix = "LIEF-%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  needs = {
    internet = {},
  },

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/libLIEF*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "lief-project",
        repo = "LIEF",
      },
    } | Attrs,

  tests = {
    parse_elf =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
          cat > test_lief.c << 'EOF'
#include <stdio.h>
#include <LIEF/LIEF.h>

int main(void) {
    Elf_Binary_t* bin = elf_parse("/bin/bash");
    if (bin == NULL) {
        fprintf(stderr, "Failed to parse ELF\n");
        return 1;
    }
    printf("ELF type: %u\n", bin->header.file_type);
    printf("ELF machine: %u\n", bin->header.machine_type);
    printf("Entry point: 0x%lx\n", (unsigned long)bin->header.entrypoint);
    elf_binary_destroy(bin);
    printf("OK\n");
    return 0;
}
EOF
          gcc test_lief.c -o test_lief -lLIEF -I/usr/include -L/usr/lib
          ./test_lief | grep -q "^OK$"
        "%
          ],
        ],
      } | Test,
  },
} | BuildSpec
