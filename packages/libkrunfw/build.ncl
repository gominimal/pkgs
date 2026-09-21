let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bc = import "../bc/build.ncl" in
let bison = import "../bison/build.ncl" in
let cpio = import "../cpio/build.ncl" in
let elfutils = import "../elfutils/build.ncl" in
let flex = import "../flex/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let m4 = import "../m4/build.ncl" in
let make = import "../make/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let patch = import "../patch/build.ncl" in
let perl = import "../perl/build.ncl" in
let pyelftools = import "../pyelftools/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "5.6.1" in
{
  name = "libkrunfw",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/containers/libkrunfw/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "b8ec9f2205f1092a5fcd8ab8ecb8e1a939dea15bb842d844da99c5a062e3f453",
      extract = true,
      strip_prefix = "libkrunfw-%{version}",
    } | Source,
    # Guest kernel firmware source, vendored so the build is hermetic (the
    # Makefile otherwise curls it into tarballs/ at build time).
    #
    # ⚠ THIS VERSION IS COUPLED TO `version` ABOVE and must be bumped with it.
    # libkrunfw's Makefile hard-pins the kernel it builds against:
    #   5.5.0:  KERNEL_VERSION = linux-6.12.91
    #   5.6.1:  KERNEL_VERSION = linux-6.12.109
    # If they disagree, the Makefile does not find its tarball under tarballs/
    # and falls back to curling it — which fails in the hermetic sandbox with
    # "make: curl: No such file or directory", not with a version error. Check
    # KERNEL_VERSION at the top of the Makefile for the tag being pinned.
    # sha256 is kernel.org's published sha256sums.asc entry for the file.
    {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.109.tar.xz",
      sha256 = "5484e552a334e15019f4aeba89e5b58f04651cf2f4e24e04de9f152f1c38e3fa",
    } | Source,
    base,
    toolchain,
    make,
    flex,
    bison,
    m4,
    bc,
    cpio,
    elfutils,
    openssl,
    perl,
    patch,
    python,
    pyelftools,
  ],

  runtime_deps = [glibc],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    libs = { glob = "usr/lib/libkrunfw.so*" } | OutputLib,
  },

  attrs = {
    upstream_version = version,
    license_spdx = "(LGPL-2.1-only AND GPL-2.0-only)",
    source_provenance = {
      category = 'GithubRepo,
      owner = "containers",
      repo = "libkrunfw",
    },
  },
} | BuildSpec
