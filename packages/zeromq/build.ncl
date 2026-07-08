# Imported from Wolfi `zeromq` by `pkgmgr import-wolfi` (cmake build),
# with outputs + runtime_deps refined from a verified `minimal package` build.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libsodium = import "../libsodium/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let patch = import "../patch/build.ncl" in
let version = "4.3.5" in
{
  name = "zeromq",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "0001-cmake-add-curve_keygen-binary.patch" } | Local,
    base,
    cmake,
    make,
    pkgconf,
    toolchain,
    glibc,
    libsodium,
    gcc,
    patch,
    {
      url = "gs://minimal-staging-archives/zeromq/libzmq/v%{version}.tar.gz",
      sha256 = "6c972d1e6a91a0ecd79c3236f04cf0126f2f4dfbbad407d72b4606a7ba93f9c6",
      extract = true,
      strip_prefix = "libzmq-%{version}",
    } | Source,
  ],
  cmd = "./build.sh",
  outputs = {
    curve_keygen = { glob = "usr/bin/curve_keygen" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
    zmq_data = { glob = "usr/share/zmq/**" } | OutputData,
  },
  runtime_deps = [glibc, subsetOf gcc ["libgcc", "libstdcpp"], libsodium],
  attrs =
    {
      upstream_version = version,
      source_provenance = { category = 'GithubRepo, owner = "zeromq", repo = "libzmq" },
      license_spdx = "MPL-2.0",
    } | Attrs,
  tests = {
    compile_link =
      {
        class = 'Standalone,
        # libzmq links libsodium, so the compile-link needs it (+ pkgconf).
        test_deps = [base, toolchain, pkgconf, libsodium],
        cmds = [
          # Compile-and-link a real libzmq consumer (ported from the -dev test),
          # then run the installed curve_keygen to confirm the bin loads.
          [
            "/bin/bash",
            "-c",
            "cat > t.c <<'EOF'\n#include <assert.h>\n#include <zmq.h>\nint main() {\n  zmq_msg_t m;\n  assert(0 == zmq_msg_init_size(&m, 1));\n  zmq_msg_close(&m);\n  return 0;\n}\nEOF\ngcc t.c -o t $(pkg-config --cflags --libs libzmq)\n./t",
          ],
          ["/bin/bash", "-c", "curve_keygen | grep -q 'CURVE PUBLIC KEY'"],
        ],
      } | Test,
  },
} | BuildSpec
