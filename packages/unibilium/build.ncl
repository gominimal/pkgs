let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let perl = import "../perl/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

# Terminfo parsing library. Upstream (mauke/unibilium) is unmaintained; the
# neovim fork is the actively maintained canonical source.
let version = "2.1.4" in
{
  name = "unibilium",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/neovim/unibilium/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7360907bcf79ba49f6fc4a504767ff86e93ab9018477026fcc70d5ab77e1f2c1",
      extract = true,
      strip_prefix = "unibilium-%{version}",
    } | Source,
    base,
    cmake,
    ninja,
    # 2.1.4 added doc/CMakeLists.txt, which generates man pages from POD and
    # hard-fails configure without pod2man:
    #   CMake Error at doc/CMakeLists.txt:9 (message):
    #     Missing pod2man.  Set CMAKE_SKIP_INSTALL_RULES to skip man pages.
    # The file did not exist in 2.1.2, so this is new work, not a regression.
    #
    # Do NOT take the error message's advice: CMAKE_SKIP_INSTALL_RULES is a
    # PROJECT-WIDE cmake variable, so setting it would also stop the library
    # and headers installing — the package would build and ship nothing.
    # pod2man ships with perl, which is already a build dep of autoconf,
    # automake, binutils and curl here, so following upstream costs nothing
    # new in the catalog and keeps the man pages rather than patching the
    # doc subdirectory out. (gzip, the other new requirement, is already
    # found via base — configure got past its check to reach pod2man.)
    perl,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],
  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libunibilium*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    # New in 2.1.4 — without an output the generated pages are built and then
    # discarded.
    mans = { glob = "usr/share/man/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "LGPL-3.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "neovim",
        repo = "unibilium",
      },
    } | Attrs,
} | BuildSpec
