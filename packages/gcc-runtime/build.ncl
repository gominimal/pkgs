let { Attrs, BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# gcc's shared runtime libraries as their own package (gominimal/inbox#1261).
# Depend on `subsetOf gcc-runtime [...]`, never `subsetOf gcc [...]`: a gcc
# subset fetches the whole compiler and its runtime_deps (see build.sh).
# Output names and globs match gcc's, so moving a consumer is a rename.
# No upstream_version: this follows the gcc build dep and rebuilds with it.
let outputs_common = {
  libgcc = { glob = "usr/lib/libgcc_s.so*", allow_data = true } | OutputLib, # libgcc_s.so is a linker-script stub
  libstdcpp = { glob = "usr/lib/libstdc++.so*" } | OutputLib,
  libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
  libatomic = { glob = "usr/lib/libatomic.so*" } | OutputLib,
}
in
{
  name = "gcc-runtime",
  build_deps = [
    { file = "build.sh" } | Local,
    bash-bootstrap,
    coreutils,
    gcc,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs =
    outputs_common
    & {
      libgfortran = { glob = "usr/lib/libgfortran.so*" } | OutputLib,
    }
    & (
      match {
        { arch = 'Amd64, .. } => { libquadmath = { glob = "usr/lib/libquadmath.so*" } | OutputLib },
        { arch = 'Arm64, .. } => {},
      } target
    ),

  attrs =
    {
      # libgcc_s, libstdc++, libgomp, libatomic, libgfortran: GPL-3.0-or-later
      # with the GCC Runtime Library Exception 3.1. libquadmath (amd64):
      # LGPL-2.1-or-later.
      license_spdx = "GPL-3.0-or-later WITH GCC-exception-3.1 AND LGPL-2.1-or-later",
    } | Attrs,

  # gcc-runtime sits on gcc's bootstrap cycle (gcc -> glibc -> python ->
  # ncurses -> gcc-runtime -> gcc). Break it with the same gominimal/bootstrap
  # gen-13 gcc objects gcc's own breaker uses. The arm64 object is C/C++ only,
  # so the breaker has no libgfortran; no package on the cycle needs it.
  replace_on_cycle =
    {
      name = "gcc-runtime (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/931b342257874bbd946a55443ba75f1930433bf4dc12d6924fec674e75f4c007/gcc-15.2.0-glibc-15.2.0-x86_64.tar.zst",
              sha256 = "931b342257874bbd946a55443ba75f1930433bf4dc12d6924fec674e75f4c007",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/4777e5fe9bd1476171abb46d6ec53f49f5e50f17a25b9ab612894d758eba5f1f/gcc-15.2.0-glibc-aarch64.tar.zst",
              sha256 = "4777e5fe9bd1476171abb46d6ec53f49f5e50f17a25b9ab612894d758eba5f1f",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [],
      outputs = outputs_common,
    } | BuildSpec,

  tests = {
    # Proves the package is self-sufficient: no gcc in this test's closure
    # (bash-bootstrap needs only glibc), so every library must resolve its own
    # DT_NEEDED against gcc-runtime + glibc alone. ld.so --list prints
    # "not found" for a missing dependency.
    loads_without_gcc =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          [
            "/bin/bash",
            "-c",
            "shopt -s nullglob; ld=(/usr/lib/ld-linux*.so.*); [ ${#ld[@]} -eq 1 ] || exit 3; for l in /usr/lib/libgcc_s.so.1 /usr/lib/libstdc++.so.6 /usr/lib/libgomp.so.1 /usr/lib/libatomic.so.1 /usr/lib/libgfortran.so.5; do [ -e \"$l\" ] || exit 4; out=$(\"${ld[0]}\" --list \"$l\") || exit 5; [[ $out == *'not found'* ]] && exit 6; done; exit 0",
          ],
        ],
      } | Test,

    # libstdc++ and the libgcc_s unwinder together: a C++ exception thrown
    # across a shared-library boundary is caught.
    cxx_exception_unwinds =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, binutils, coreutils, gcc],
        cmds = [
          ["/bin/bash", "-c", "printf '%s\\n' '#include <stdexcept>' 'int boom(int x) { if (x) throw std::runtime_error(\"x\"); return 0; }' > boom.cc"],
          ["/bin/bash", "-c", "printf '%s\\n' '#include <stdexcept>' 'int boom(int);' 'int main() { try { boom(1); } catch (const std::runtime_error &) { return 0; } return 1; }' > main.cc"],
          ["/bin/g++", "-shared", "-fPIC", "boom.cc", "-o", "libboom.so"],
          ["/bin/g++", "main.cc", "-L.", "-lboom", "-Wl,-rpath,$ORIGIN", "-o", "main"],
          ["/bin/bash", "-c", "./main"],
        ],
      } | Test,
  },
}
