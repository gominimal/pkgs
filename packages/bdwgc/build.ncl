let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# The Boehm-Demers-Weiser conservative garbage collector (libgc), Guile's allocator.
let version = "8.2.12" in
{
  name = "bdwgc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gc-%{version}.tar.gz",
      sha256 = "42e5194ad06ab6ffb806c83eb99c03462b495d979cda782f3c72c08af833cd4e",
      extract = true,
      strip_prefix = "gc-%{version}",
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
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      repology_project = "boehm-gc",
      source_provenance = {
        category = 'GithubRepo,
        owner = "ivmai",
        repo = "bdwgc",
      },
    } | Attrs,

  tests = {
    # allocates through the collector and forces a collection
    gc_alloc =
      {
        class = 'Standalone,
        test_deps = [base, toolchain],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <gc.h>\\nint main(void){GC_INIT();for(int i=0;i<100000;i++){char *p=GC_MALLOC(64);p[0]=1;}GC_gcollect();return GC_get_gc_no()==0;}\\n' > t.c && gcc -o t t.c -lgc && ./t"],
        ],
      } | Test,
  },
} | BuildSpec
