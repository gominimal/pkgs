# LLVM 23, prefixed under /usr/lib/llvm-23 (see ../llvm/versioned.ncl). For consumers that
# need LLVM 23 (bun 1.4, pkgs#1057) and the eventual default-llvm move.
# The record literal lives here, not in the helper: minimal identifies a package by the
# source position of its BuildSpec record, so two packages sharing one literal collapse
# into one.
let { Attrs, BuildSpec, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let version = "23.1.5" in
let llvm = (import "../llvm/versioned.ncl") version "fb50b1eac93ddeb3aa8dab4cfe324dff74f4a9c2bdee6160c9e36188f8d06a6e" in
let prefix = llvm.prefix in
{
  name = llvm.name,
  build_deps = llvm.build_deps,
  runtime_deps = llvm.runtime_deps,
  cmd = llvm.cmd,
  build_args = llvm.build_args,
  outputs = llvm.outputs,
  tests = {
    versions =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "%{prefix}/bin/clang --version | grep -F 'clang version %{version}'"],
          ["/bin/bash", "-c", "test \"$(%{prefix}/bin/llvm-config --version)\" = %{version}"],
          ["/bin/bash", "-c", "%{prefix}/bin/ld.lld --version | grep -F 'LLD %{version}'"],
        ],
      } | Test,
    hello_clang_lld =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, glibc, gcc, grep],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <stdio.h>\\nint main(void){puts(\"hello llvm-23\");return 0;}\\n' > hello.c"],
          ["%{prefix}/bin/clang", "-fuse-ld=lld", "hello.c", "-o", "hello"],
          ["/bin/bash", "-c", "./hello | grep -qx 'hello llvm-23'"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "llvm",
        repo = "llvm-project",
      },
      build_cost_multiple = 6,
    } | Attrs,
} | BuildSpec
