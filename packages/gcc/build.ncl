let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
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
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gcc-%{version}.tar.xz",
      sha256 = "438fd996826b0c82485a29da03a72d71d6e3541a83ec702df4271f6fe025d24e"
    } | Source,
    # base
    bash,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk,
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
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libs = { glob = "usr/lib/**/*.{a,o,so*}", allow_data = true } | OutputLib, # allows data as a few .so's are stubs that don't parse in our checker
    libatomic = { glob = "usr/lib/libatomic.so*" } | OutputLib,

    libgcc = { glob = "usr/lib/libgcc_s.so*", allow_data = true } | OutputLib, # allows data as libgcc_s.so is a stub that does not parse in our checker
    libgomp = { glob = "usr/lib/libgomp.so*" } | OutputLib,
    libstdcpp = { glob = "usr/lib/libstdc++*.so*", allow_data = true } | OutputLib, # libstdc++.so.6.0.34-gdb.py...

    libs_all = { glob = "usr/lib/**", allow_executable = true } | OutputData,
    share_data = { glob = "usr/share/gcc-*/**" } | OutputData,
    ltconfigs = { glob = "usr/lib/**/*.la" } | OutputData,

    # Wildcards are target/version
    libexec_bins = { glob = "usr/libexec/gcc/*/*/{cc1,cc1plus,f951,collect2,lto1,lto-wrapper}" } | OutputBin,
    libexec_libs = { glob = "usr/libexec/gcc/*/*/g++-mapper-server" } | OutputLib,
    plugins = { glob = "usr/libexec/gcc/*/*/plugin/*" } | OutputBin,
    install_tools = { glob = "usr/libexec/gcc/*/*/install-tools/*" } | OutputBin,

    liblto_plugin = { glob = "usr/libexec/gcc/*/*/liblto_plugin.so" } | OutputLib,
    lto_plugin_ltconfig = { glob = "usr/libexec/gcc/*/*/liblto_plugin.la" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "gcc",
      source_provenance = {
        category = 'GnuProject,
        name = "gcc",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "gcc (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gcc/90c1cc369996f1dca2e3e8aac418822dce19cc9216a05e620e434fb599f28a24.tar.zst",
              sha256 = "16a7b18a04e465f65fd09e8b610390c9ba12b3a0c1d170a28fa1d22b552787f5",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/gcc/arm64-linux-gnu/gcc_12.4.0_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "1ef95ce51de775151d0afe0c9e955bda9ec5e7ce85ed6a13aa35a36fedc6c9f0",
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
        test_deps = [bash, binutils, coreutils], # TODO: Some of these need to be runtime_deps
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
        test_deps = [bash, binutils, coreutils, grep], # TODO: Some of these need to be runtime_deps
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
        test_deps = [bash, binutils, coreutils, grep], # TODO: Some of these need to be runtime_deps
        cmds = [
          ["/bin/bash", "-c", "cat > math.c << 'EOF'\n#include <stdio.h>\nint main() {\n    int result = 2 + 2;\n    printf(\"%d\", result);\n    return 0;\n}\nEOF"],
          ["/bin/gcc", "math.c", "-o", "math"],
          ["/bin/bash", "-c", "./math | grep -q '^4$'"],
        ],
      } | Test,

    compile_exec_linking =
      {
        class = 'Standalone,
        test_deps = [bash, binutils, coreutils, grep], # TODO: Some of these need to be runtime_deps
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
