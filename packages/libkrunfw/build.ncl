let { BuildSpec, Local, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
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

let version = "5.6.4" in
let kernel_version = "6.12.115" in
{
  name = "libkrunfw",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/libkrun/libkrunfw/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "5b92b6f2a5ee6a16583bd37014a37794451a00d120fceee104f84404118757d0",
      extract = true,
      strip_prefix = "libkrunfw-%{version}",
    } | Source,
    # Guest kernel source, vendored so the build is hermetic (the Makefile
    # otherwise curls it into tarballs/ at build time).
    #
    # As of 5.6.4 libkrunfw no longer builds a vanilla kernel.org tarball plus
    # its own patches/ (5.6.1 still used linux-6.12.109.tar.xz): it fetches a
    # pre-patched tree from libkrun/linux, tagged
    # v<FULL_VERSION>-<KERNEL_VERSION>, and its Makefile pins both:
    #   KERNEL_VERSION = 6.12.115   (5.6.4)
    #   KERNEL_TARBALL = tarballs/v$(FULL_VERSION)-$(KERNEL_VERSION).tar.gz
    # ⚠ `kernel_version` must match KERNEL_VERSION at the top of the Makefile
    # for the tag being pinned. build.sh checks this and fails loudly; without
    # the check a mismatch surfaces only as "make: curl: No such file or
    # directory".
    #
    # sha256 is of GitHub's tag archive (codeload), verified to carry commit
    # cb18e1849e6f8d8866f5e6f65fd428f1846726d4 (the tag's target) and the
    # top-level dir linux-5.6.4-6.12.115/ the Makefile untars to. This relies
    # on GitHub's archive bytes staying stable, as other tag-archive Sources here do.
    {
      url = "https://github.com/libkrun/linux/archive/refs/tags/v%{version}-%{kernel_version}.tar.gz",
      sha256 = "050fcea96b607e49f135f270472bc95346c172c9d6df5f9256aeb6f7972675d5",
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
      owner = "libkrun",
      repo = "libkrunfw",
    },
  },

  tests = {
    smoketest =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, toolchain],
        cmds = [
          [
            "/usr/bin/bash",
            "-c",
            m%%"
              set -e
              gcc -x c - -o t -lkrunfw <<'EOF'
              extern void krunfw_get_kernel(void);
              int main(void) { void *volatile p = (void *)krunfw_get_kernel; return p ? 0 : 1; }
              EOF
              ./t
            "%%
          ],
        ],
      } | Test,
  },
} | BuildSpec
