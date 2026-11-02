let { BuildSpec, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
{
  name = "toolchain",
  build_deps = [],
  runtime_deps = [
    binutils,
    gcc,
    glibc,
    linux_headers,
  ],
  cmd = "",
  outputs = {},

  # A box that adds `toolchain` must be able to build and run a trivial program with nothing else:
  # test_deps are only the shell and coreutils the commands themselves need, so as/ld, crt files,
  # libc and the kernel headers all have to come from toolchain's own closure.
  tests = {
    c_hello =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <stdio.h>\\nint main(void) { puts(\"hi\"); return 0; }\\n' > h.c"],
          ["/bin/gcc", "h.c", "-o", "h"],
          ["/bin/bash", "-c", "test \"$(./h)\" = hi"],
          # `cc` is the name make's implicit rules, cc-rs and rustc's default linker invoke
          ["/bin/cc", "h.c", "-o", "h-cc"],
          ["/bin/bash", "-c", "test \"$(./h-cc)\" = hi"],
        ],
      } | Test,

    cxx_kernel_headers_hello =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <linux/types.h>\\n#include <iostream>\\nint main() { __u32 x = 42; std::cout << x << std::endl; return 0; }\\n' > h.cc"],
          ["/bin/g++", "h.cc", "-o", "hcc"],
          ["/bin/bash", "-c", "test \"$(./hcc)\" = 42"],
        ],
      } | Test,
  },
} | BuildSpec
