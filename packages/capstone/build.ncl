let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "5.0.9" in
{
  name = "capstone",
  build_deps = [
    { file = "build.sh" } | Local,
    base,
    cmake,
    ninja,
    pkgconf,
    toolchain,
    glibc,
    {
      url = "https://github.com/capstone-engine/capstone/archive/refs/tags/%{version}.tar.gz",
      sha256 = "0619da31af08152600af95c481527ef6d756c0a8404fca7544a4fdf6dfc2c0f9",
      extract = true,
      strip_prefix = "capstone-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    cstool = { glob = "usr/bin/cstool" } | OutputBin,
    libs = { glob = "usr/lib/libcapstone.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    cmake_files = { glob = "usr/lib/cmake/**" } | OutputData,
  },
  runtime_deps = [glibc],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "capstone-engine", repo = "capstone" },
      # BSD-3-Clause (LICENSE.TXT). The tree also carries LICENSE_LLVM.TXT —
      # Apache-2.0 WITH LLVM-exception — covering the arch decoders generated
      # from LLVM's tables. Both are permissive; BSD-3-Clause is the stricter
      # on attribution, so it is the honest single value.
      license_spdx = "BSD-3-Clause",
    } | Attrs,
  tests = {
    smoketest = standaloneTest "/bin/cstool -v",

    # DISASSEMBLE, don't just run --version.
    #
    # The failure this guards is a build that works and is quietly less
    # capable. `CAPSTONE_ARCHITECTURE_DEFAULT` gates every per-arch
    # `CAPSTONE_<ARCH>_SUPPORT` option, so changing one value drops whole
    # architectures out of the library while cstool still builds, still runs,
    # and still reports the same version. Nothing else here would notice:
    # `enumerate bins` sees a binary, `output types valid` sees a .so, a
    # smoke test sees a version string.
    #
    # So the assertions are real instructions on real bytes, including two
    # fringe architectures — the ones a "slim it down" change removes first,
    # and the ones an RE workbench misses last.
    disassembles =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # x86-64: push rbp / mov rbp, rsp — the universal function prologue.
          ["/bin/bash", "-c", "cstool x64 '554889e5' | grep -qi push && cstool x64 '554889e5' | grep -qi mov"],
          # arm64: mul x1, x1, x2 — capstone's own test vector.
          ["/bin/bash", "-c", "cstool arm64 '217c029b' | grep -qi mul"],
          # 32-bit ARM: a branch-with-link.
          ["/bin/bash", "-c", "cstool arm 'edffffeb' | grep -qi bl"],
          # Fringe #1 — riscv64 (0x00000013 = nop).
          ["/bin/bash", "-c", "cstool riscv64 '13000000' | grep -qiE 'nop|addi'"],
          # Fringe #2 — ppc64, BIG-endian. `ppc64` alone is CS_MODE_LITTLE_ENDIAN
          # in capstone 5 (cstool.c: "ppc64" => CS_MODE_64|CS_MODE_LITTLE_ENDIAN),
          # and 7c0802a6 is the big-endian encoding of `mflr r0` — the mode
          # name has to match the bytes or this decodes to garbage. Caught by
          # running it: the first version used `ppc64` and failed.
          ["/bin/bash", "-c", "cstool ppc64be '7c0802a6' | grep -qi mflr"],
          # CONTROL: an architecture that does not exist must FAIL. Without
          # this, every grep above could be matching an error message rather
          # than disassembly, and the whole test would prove nothing.
          ["/bin/bash", "-c", "! cstool no-such-arch 00 >/dev/null 2>&1"],
        ],
      } | Test,

    # The shared library is the reason to package this rather than let each
    # consumer vendor it. `BUILD_SHARED_LIBS` defaults to **OFF** upstream, so
    # a stock build produces libcapstone.a only — and anything linking that
    # absorbs capstone statically, making a capstone CVE invisible to pkgscan.
    # That default is one line in build.sh away from silently coming back.
    ships_shared_lib =
      {
        class = 'Standalone,
        test_deps = [base, pkgconf],
        cmds = [
          ["/bin/bash", "-c", "test -e /usr/lib/libcapstone.so"],
          # A real versioned SONAME, not just the dev symlink.
          ["/bin/bash", "-c", "ls /usr/lib/libcapstone.so.* >/dev/null 2>&1"],
          # ...and no static archive, so nobody links it by accident.
          ["/bin/bash", "-c", "! test -e /usr/lib/libcapstone.a"],
          # pkg-config must resolve, or a downstream build quietly falls back
          # to its own vendored capstone.
          ["/bin/bash", "-c", "PKG_CONFIG_PATH=/usr/lib/pkgconfig pkg-config --exists capstone"],
        ],
      } | Test,
  },
} | BuildSpec
