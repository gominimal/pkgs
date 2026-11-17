let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# other
let gmp = import "../gmp/build.ncl" in
let mpc = import "../mpc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let version = "15.2.0" in
{
  name = "gcc",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gcc-%{version}.tar.xz",
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e"
    } | Source,
    # base
    bash-bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk-bootstrap,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    glibc,
    linux_headers,
    # other
    gmp,
    mpc,
    mpfr,
    zlib,
    zstd,
  ],
  runtime_deps = [
    gmp,
    mpc,
    mpfr,
    zlib,
    zstd,
  ],

  cmd = "./build.sh",
  # The outputs of the registry spec's gcc example (gominimal/arch#183,
  # specs/registry/nickel/examples/packages/gcc/build.ncl), in today's run-time
  # kinds: no file is in two outputs. Checked against the gcc 16.2.0 canary
  # artifacts (pkgs#1340: 1,823 files on amd64, 1,700 on arm64) and main's gcc
  # 15.2.0 ones: each file in exactly one output, no output empty. The
  # differences from the example: libssp is its own output (stlink needs only
  # it), and runtime_stage is the copy gcc-runtime repacks (build.sh). When the
  # spec's per-output runtime_deps land, the library outputs take ["glibc"] and
  # their gcc siblings, as in the example; until then the package's list holds.
  # The old catch-alls (libs, libs_all) and their flags are gone; outputs that
  # took their files keep allow_data / allow_executable.
  outputs =
    {
      # Run-time libraries, the outputs consumers name (today through gcc-runtime).
      libgcc = { glob = "usr/lib/libgcc_s*.so*", allow_data = true } | OutputLib, # libgcc_s.so and gcc 16's libgcc_s_asneeded.so are linker scripts
      libstdcpp = { glob = "usr/lib/libstdc++*.so*", allow_data = true } | OutputLib, # libstdc++.so.6.*-gdb.py
      libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
      libatomic = { glob = "usr/lib/libatomic*.so*", allow_data = true } | OutputLib, # gcc 16's libatomic_asneeded.so is a linker script
      libgfortran = { glob = "usr/lib/libgfortran.so*" } | OutputLib,
      libssp = { glob = "usr/lib/libssp.so*" } | OutputLib,
      sanitizers = { glob = "usr/lib/lib{asan,hwasan,lsan,tsan,ubsan}.so*" } | OutputLib,
      libs_other = { glob = "usr/lib/lib{cc1,itm}.so*" } | OutputLib,
      runtime_stage = { glob = "usr/lib/gcc-runtime-stage/**", allow_data = true } | OutputLib,

      # The compilers, and what they compile and link with.
      bins = { glob = "usr/bin/*" } | OutputBin,
      # Wildcards are target/version
      libexec_bins = { glob = "usr/libexec/gcc/*/*/{cc1,cc1plus,f951,collect2,lto1,lto-wrapper}" } | OutputBin,
      libexec_libs = { glob = "usr/libexec/gcc/*/*/g++-mapper-server" } | OutputLib,
      plugins = { glob = "usr/libexec/gcc/*/*/plugin/*" } | OutputBin,
      # mkinstalldirs technically needs /bin/sh but depending on bash at this package would be difficult, ignore lint for now
      install_tools = { glob = "usr/libexec/gcc/*/*/install-tools/*", allow_missing_interpreter = true } | OutputBin,
      liblto_plugin = { glob = "usr/libexec/gcc/*/*/liblto_plugin.so" } | OutputLib,
      gcc_objects = { glob = "usr/lib/gcc/*/*/*", allow_data = true } | OutputLib,
      gcc_headers = { glob = "usr/lib/gcc/*/*/{include,include-fixed,finclude}/**", allow_executable = true } | OutputData,
      gcc_install_tools = { glob = "usr/lib/gcc/*/*/install-tools/**", allow_executable = true } | OutputData,
      includes = { glob = "usr/include/**" } | OutputData,
      static_libs = { glob = "usr/lib/*.{a,o}", allow_data = true } | OutputLib,
      specs = { glob = "usr/lib/*.{spec,json}" } | OutputData,
      share_data = { glob = "usr/share/gcc-*/**" } | OutputData,

      # The spec's `dev` and `doc` kinds, as data until min has them.
      ltconfigs = { glob = "usr/lib/*.la" } | OutputData,
      lto_plugin_ltconfig = { glob = "usr/libexec/gcc/*/*/liblto_plugin.la" } | OutputData,
      plugin_dev = { glob = "usr/lib/gcc/*/*/plugin/**", allow_executable = true } | OutputData,
      mans = { glob = "usr/share/man/**" } | OutputData,
      ..
    }
      | match {
        { arch = 'Amd64, .. } =>
          {
            libquadmath = { glob = "usr/lib/libquadmath*.so*" } | OutputLib,
            ..
          },
        { arch = 'Arm64, .. } => { .. },
      } target,

  attrs =
    {
      upstream_version = version,
      license_spdx = "(GPL-2.0-only AND GPL-3.0-only AND LGPL-2.1-only)",
      repology_project = "gcc",
      source_provenance = {
        category = 'GnuProject,
        name = "gcc",
      },
      build_cost_multiple = 2,
    } | Attrs,

  replace_on_cycle =
    {
      name = "gcc (prebuilt)",
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
              # gominimal/bootstrap gen-17 object (generations/gen-17/manifest.json)
              url = "gs://minimal-bootstrap/gen-17/sha256/ad09a27cf021c341d50cf5c7a43d9cfcb45af363890c8e0b695259edc2c27d43/gcc-15.2.0-glibc-seed-15.2.0-aarch64.tar.zst",
              sha256 = "ad09a27cf021c341d50cf5c7a43d9cfcb45af363890c8e0b695259edc2c27d43",
              extract = true,
            } | Source,
        } target,
      ],
      runtime_deps = [
        gmp,
        mpc,
        mpfr,
        zlib,
        zstd,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,

        libgcc = { glob = "usr/lib/libgcc_s.so*" } | OutputLib,
        libstdcpp = { glob = "usr/lib/libstdc++*.so*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    compile_exec_code =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, binutils, coreutils], # TODO: Some of these need to be runtime_deps
        cmds = [
          ["/bin/bash", "-c", "echo 'int main() { return 0; }' > hello.c"],
          ["/bin/gcc", "hello.c", "-o", "hello"],
          ["/bin/bash", "-c", "./hello"], # verify it runs and returns 0
          ["/bin/bash", "-c", "./hello; test $? -eq 0"], # explicitly check exit code
        ],
      } | Test,

    compile_exec_output =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, binutils, coreutils, grep], # TODO: Some of these need to be runtime_deps
        cmds = [
          ["/bin/bash", "-c", "cat > print.c << 'EOF'\n#include <stdio.h>\nint main() {\n    printf(\"Hello World\");\n    return 0;\n}\nEOF"],
          ["/bin/gcc", "print.c", "-o", "print"],
          ["/bin/bash", "-c", "./print > output.txt"],
          ["/bin/bash", "-c", "grep -q '^Hello World$' output.txt"],
        ],
      } | Test,

    compile_exec_math =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, binutils, coreutils, grep], # TODO: Some of these need to be runtime_deps
        cmds = [
          ["/bin/bash", "-c", "cat > math.c << 'EOF'\n#include <stdio.h>\nint main() {\n    int result = 2 + 2;\n    printf(\"%d\", result);\n    return 0;\n}\nEOF"],
          ["/bin/gcc", "math.c", "-o", "math"],
          ["/bin/bash", "-c", "./math | grep -q '^4$'"],
        ],
      } | Test,

    compile_exec_linking =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, binutils, coreutils, grep], # TODO: Some of these need to be runtime_deps
        cmds = [
          ["/bin/bash", "-c", "cat > func.c << 'EOF'\nint multiply(int a, int b) {\n    return a * b;\n}\nEOF"],
          ["/bin/bash", "-c", "cat > main.c << 'EOF'\n#include <stdio.h>\nint multiply(int a, int b);\nint main() {\n    printf(\"%d\", multiply(6, 7));\n    return 0;\n}\nEOF"],
          ["/bin/gcc", "-c", "func.c", "-o", "func.o"],
          ["/bin/gcc", "-c", "main.c", "-o", "main.o"],
          ["/bin/gcc", "main.o", "func.o", "-o", "multi"],
          ["/bin/bash", "-c", "./multi | grep -q '^42$'"],
        ],
      } | Test,
  },
} | BuildSpec
