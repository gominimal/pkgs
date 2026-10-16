let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let make = import "../make/build.ncl" in

# wasi-libc has no releases of its own; it is tagged with the wasi-sdk release
# that ships it. wasi-sdk-21 is commit c5264e2b, packaged by Alpine as 0.20231215.
let tag = "wasi-sdk-21" in
{
  name = "wasi-libc",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/wasi-libc-%{tag}.tar.gz",
      sha256 = "4a2a3e3b120ba1163c57f34ac79c3de720a8355ee3a753d81f1f0c58c4cf6017",
      extract = true,
      strip_prefix = "wasi-libc-%{tag}",
    } | Source,
    base,
    llvm, # clang, llvm-ar, llvm-nm
    make,
  ],

  cmd = "./build.sh",
  outputs = {
    # wasm32 objects and archives, not ELF.
    libs = { glob = "usr/lib/wasi/lib/wasm32-wasi/*.{a,o}", allow_data = true } | OutputLib,
    includes = { glob = "usr/lib/wasi/include/**" } | OutputData,
    licenses = { glob = "usr/share/licenses/wasi-libc/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = "0.20231215",
      license_spdx = "(Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT) AND CC0-1.0 AND BSD-2-Clause AND MIT",
      repology_project = "wasi-libc",
      source_provenance = {
        category = 'GithubRepo,
        owner = "WebAssembly",
        repo = "wasi-libc",
      },
    } | Attrs,

  tests = {
    # memcpy/memset lowered to memory.copy/memory.fill means the build picked up
    # clang 21's default CPU instead of the pinned feature set.
    no_bulk_memory =
      {
        class = 'Standalone,
        test_deps = [base, llvm],
        cmds = [
          ["/bin/bash", "-c", "set -eu; L=/usr/lib/wasi/lib/wasm32-wasi; llvm-objdump -d $L/libc.a $L/crt1-reactor.o > dis.txt; test -s dis.txt; ! grep -Eq 'memory\\.(copy|fill)|i(32|64)\\.trunc_sat' dis.txt"],
        ],
      } | Test,

    # A reactor module exporting malloc/free, the shape llhttp is linked in.
    # -nodefaultlibs skips the compiler-rt builtins clang otherwise adds.
    reactor_link =
      {
        class = 'Standalone,
        test_deps = [base, llvm],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <string.h>\\nint f(char *d, const char *s, int n) { memcpy(d, s, n); return (int)strlen(d); }\\n' > t.c"],
          ["/bin/bash", "-c", "set -eu; clang --target=wasm32-wasi --sysroot=/usr/lib/wasi -mcpu=mvp -mmutable-globals -O2 -mexec-model=reactor -nodefaultlibs -Wl,--export=malloc -Wl,--export=free -Wl,--export=f -Wl,--no-entry -Wl,--strip-all -o t.wasm t.c -lc; test \"$(head -c 4 t.wasm | od -An -tx1 | tr -d ' ')\" = 0061736d"],
        ],
      } | Test,
  },
} | BuildSpec
