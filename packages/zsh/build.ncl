let { Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let libcap = import "../libcap/build.ncl" in

let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "5.9" in
{
  name = "zsh",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://www.zsh.org/pub/old/zsh-%{version}.tar.xz",
      sha256 = "9b8d1ecedd5b5e81fbf1918e876752a7dd948e05c1a0dba10ab863842d45acd5",
      extract = true,
      strip_prefix = "zsh-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    ncurses,
  ],

  runtime_deps = [
    glibc,
    ncurses,
    gdbm,
    libcap,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    zsh = { glob = "usr/bin/zsh" } | OutputBin,

    functions = { glob = "usr/share/zsh/%{version}/functions/**" } | OutputData,
    help = { glob = "usr/share/zsh/%{version}/help/**" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT-Modern-Variant",
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/zsh", "--version"],
        ],
      } | Test,
    basic_echo =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/zsh", "-c", "echo hello"],
        ],
      } | Test,
    arithmetic =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/zsh", "-c", "echo $((2 + 2))"],
        ],
      } | Test,
  },
} | BuildSpec
