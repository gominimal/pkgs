let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let ncurses = import "../ncurses/build.ncl" in
let gdbm = import "../gdbm/build.ncl" in
let libcap = import "../libcap/build.ncl" in

let coreutils = import "../coreutils/build.ncl" in
let grep = import "../grep/build.ncl" in

let version = "5.9.2" in
{
  name = "zsh",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Sourced from the gs:// mirror so the pin stays fetchable: zsh moves the
      # current release to /pub/old/ once superseded, so a hardcoded /pub/old/
      # (or /pub/) URL rots. On update, pkgmgr re-mirrors from the canonical
      # /pub/ (see upstream_sources.rs `zsh`). Mirror of the /pub/old/ tarball.
      url = "gs://minimal-staging-archives/zsh-%{version}.tar.xz",
      sha256 = "36fa734374b44783582cec09bcd67822e2f992c779ec1624ab5596df078d2f81",
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

    # zsh is modular: the line editor (`zsh/zle`), the completion system
    # (`zsh/complete`, `zsh/computil`) and the rest are dlopened at run
    # time from here, not linked into the binary. Without them an
    # interactive shell starts and then fails at its first prompt with
    # `failed to load module 'zsh/zle'`, which no non-interactive test
    # catches. Recursive because some modules are namespaced into
    # subdirectories — `zsh/db/gdbm` (this build passes `--enable-gdbm`)
    # installs at `zsh/db/gdbm.so`.
    modules = { glob = "usr/lib/zsh/%{version}/**" } | OutputLib,

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
    # The tests above all passed while the package shipped no modules at
    # all: `--version`, `-c` and arithmetic are built in, so none of them
    # touches `usr/lib/zsh`. These two do. `zmodload` exits non-zero when
    # it cannot find a module, so the load is the assertion.
    modules_load =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/zsh", "-c", "zmodload zsh/complete zsh/parameter zsh/zutil"],
        ],
      } | Test,
    # `zsh/zle` by path rather than by load: it is the module an
    # interactive shell reaches for first, and the one whose absence was
    # the visible break, but it is the line editor — asserting it is
    # installed does not depend on how it behaves without a terminal.
    zle_module_installed =
      {
        class = 'Standalone,
        test_deps = [coreutils, grep],
        cmds = [
          ["/usr/bin/zsh", "-c", "test -e /usr/lib/zsh/%{version}/zsh/zle.so"],
        ],
      } | Test,
  },
} | BuildSpec
