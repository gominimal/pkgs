# Imported from Wolfi `jemalloc` by `pkgmgr import-wolfi` (autotools build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let autoconf = import "../autoconf/build.ncl" in
let automake = import "../automake/build.ncl" in
let libtool = import "../libtool/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let patch = import "../patch/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let version = "5.3.1" in
{
  name = "jemalloc",
  build_deps = [
    { file = "build.sh" } | Local,
    # gcc-16 build fix — upstream cherry-pick 1a15fe33 (#2900), matching Wolfi.
    # Inert on gcc-15 (current); prevents FTBFS once gcc bumps to 16.
    { file = "jemalloc-gcc16-cxx-exceptions.patch" } | Local,
    base,
    autoconf,
    automake,
    libtool,
    m4,
    make,
    patch,
    pkgconf,
    toolchain,
    glibc,
    gcc,
    {
      url = "gs://minimal-staging-archives/jemalloc/jemalloc/%{version}.tar.gz",
      sha256 = "7b30f6116f11d736badd48c903cba2b3344a88d62e3a7b892434f870e860b1c0",
      extract = true,
      strip_prefix = "jemalloc-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  # The git-archive tarball has no VERSION file / .git, so jemalloc's configure
  # would stamp a bogus 0.0.0 into jemalloc.pc / jemalloc.h. Pass the real
  # version through so build.sh can write VERSION before ./configure.
  build_args = {
    include version,
  },
  outputs = {
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    # jemalloc-config reports the build's flags — a POSIX-sh script, so the
    # interpreter check is waived (cf. pcre2-config). jeprof (perl) is NOT
    # shipped: it would need a perl runtime_dep to be a working tool.
    config = { glob = "usr/bin/jemalloc-config", allow_missing_interpreter = true } | OutputBin,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc", "libstdcpp"]],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "jemalloc", repo = "jemalloc" },
      license_spdx = "BSD-2-Clause",
    } | Attrs,

  tests = {
    compile_link =
      {
        class = 'Standalone,
        test_deps = [base, toolchain, pkgconf],
        cmds = [
          # Compile-link-RUN a real jemalloc consumer, and lock the version-stamp
          # fix (jemalloc-config must report 5.3.1, not the git-archive 0.0.0).
          [
            "/bin/bash",
            "-c",
            "cat > t.c <<'EOF'\n#include <jemalloc/jemalloc.h>\n#include <stdio.h>\nint main() {\n  void *p = mallocx(64, 0);\n  if (!p) return 1;\n  dallocx(p, 0);\n  printf(\"ok\\n\");\n  return 0;\n}\nEOF\ngcc t.c -o t $(pkg-config --cflags --libs jemalloc)\n./t | grep -q '^ok$'",
          ],
          ["/bin/bash", "-c", "jemalloc-config --version | grep -q '^5.3.1'"],
        ],
      } | Test,
  },
} | BuildSpec
