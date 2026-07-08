let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let pkgconf = import "../pkgconf/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let bash = import "../bash/build.ncl" in
let util-linux = import "../util-linux/build.ncl" in

let version = "1.47.4" in
{
  name = "e2fsprogs",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v%{version}/e2fsprogs-%{version}.tar.xz",
      sha256 = "fd5bf388cbdbe006a3d3b318d983b2948382440acc85a87f1e7d108653e8db0b"
    } | Source,
    base-bootstrap,
    make,
    pkgconf,
    toolchain,
  ],
  # util-linux provides libblkid/libuuid: build.sh configures --disable-libblkid
  # --disable-libuuid so e2fsprogs's tools link util-linux's maintained,
  # symbol-versioned libs instead of bundling its own older forks (same soname,
  # which otherwise collide in a shared image). Needed both to link at build and
  # to load at runtime. Cycle-safe: nothing in util-linux's closure uses
  # e2fsprogs.
  runtime_deps = [
    glibc,
    bash,
    util-linux,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    chattr = { glob = "usr/bin/chattr" } | OutputBin,
    lsattr = { glob = "usr/bin/lsattr" } | OutputBin,
    compile_et = { glob = "usr/bin/compile_et" } | OutputBin,
    mk_cmds = { glob = "usr/bin/mk_cmds" } | OutputBin,
    sbins = { glob = "usr/sbin/*" } | OutputBin,

    # libblkid/libuuid are intentionally not built here (--disable-libblkid
    # --disable-libuuid); util-linux is the sole provider. See build.sh.
    libext2fs = { glob = "usr/lib/libext2fs*.so*" } | OutputLib,
    libcom_err = { glob = "usr/lib/libcom_err*.so*" } | OutputLib,
    libe2p = { glob = "usr/lib/libe2p*.so*" } | OutputLib,
    libss = { glob = "usr/lib/libss*.so*" } | OutputLib,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,

    includes = { glob = "usr/include/**/*" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-2.0-only AND LGPL-2.0-only AND BSD-3-Clause AND MIT",
    } | Attrs,
} | BuildSpec
