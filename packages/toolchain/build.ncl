let { BuildSpec, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# The C/C++ toolchain as one name: the compiler (gcc), its assembler and linker
# (binutils), and the libc and kernel headers a program compiles against (glibc,
# linux_headers). A compiler package names only its own parts; a box that compiles
# lists `toolchain` (gominimal/arch#183: the group supplies binutils and the headers,
# not each compiler's runtime_deps). pkgs#805 asked for "add one package, build
# hello-world"; this is that package, and its tests are that promise.
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

  tests = {
    # `cc` (gcc installs it) assembles and links through binutils; nothing beyond
    # the group and a shell.
    hello_c =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <stdio.h>\\nint main(void){puts(\"hello c\");return 0;}\\n' > h.c && cc h.c -o h && [ \"$(./h)\" = 'hello c' ]"],
        ],
      } | Test,
    # The kernel headers come from the group too (the #805 failure: <linux/types.h>
    # not found with gcc alone).
    hello_cxx_linux_headers =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <linux/types.h>\\n#include <iostream>\\nint main(){__u32 x=42; std::cout << \"hello c++ \" << x << std::endl;}\\n' > h.cc && g++ h.cc -o h && [ \"$(./h)\" = 'hello c++ 42' ]"],
        ],
      } | Test,
  },
} | BuildSpec
